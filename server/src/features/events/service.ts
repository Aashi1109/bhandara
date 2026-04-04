import AddressService from '@/features/addresses/service';
import { Address } from '@/features/addresses/model';
import { EAddressEntityType, EEventParticipantStatus, EEventStatus, type EEventType } from '@/definitions/enums';
import type { IBaseThread, IBaseUser, IEvent, IPaginationParams, PaginatedResult } from '@/definitions/types';
import ThreadsService from '../threads/service';
import { findAllWithPagination } from '@/utils/dbUtils';
import { Op, Sequelize, type WhereOptions } from 'sequelize';
import TagService from '../tags/service';
import MediaService from '../media/service';
import UserService from '../users/service';
import ReactionService from '../reactions/service';
import { validateEventCreate, validateEventUpdate } from './validation';
import { getEventCache, getEventUsersCache, setEventCache, setEventUsersCache, deleteEventCache } from './helpers';
import { isEmpty } from '@/utils';
import { BadRequestError, NotFoundError } from '@/exceptions';
import { getDistanceInMeters } from '@/helpers';
import { Event } from './model';
import MessageService from '@/features/messages/service';
import EntityStatsService from '@/features/stats/service';
import { deriveEventStatus, resolveEventStatus } from './status';
import ngeohash from 'ngeohash';

export interface IEventListFilters {
  createdBy?: string;
  statuses?: EEventStatus[];
  tagIds?: string[];
  types?: EEventType[];
  latitude?: number;
  longitude?: number;
  radiusKm?: number;
  startDate?: Date;
  endDate?: Date;
}

type IEventSummary = Pick<
  IEvent,
  'id' | 'name' | 'status' | 'type' | 'createdBy' | 'location' | 'timings' | 'createdAt' | 'updatedAt' | 'media'
>;

class EventService {
  private readonly addressService: AddressService;
  private readonly threadService: ThreadsService;
  private readonly tagService: TagService;
  private readonly mediaService: MediaService;
  private readonly userService: UserService;
  private readonly reactionService: ReactionService;
  private readonly messageService: MessageService;
  private readonly entityStatsService: EntityStatsService;
  private readonly getCache = getEventCache;
  private readonly setCache = setEventCache;
  private readonly deleteCache = deleteEventCache;

  constructor() {
    this.addressService = new AddressService();
    this.threadService = new ThreadsService();
    this.tagService = new TagService();
    this.mediaService = new MediaService();
    this.userService = new UserService();
    this.reactionService = new ReactionService();
    this.messageService = new MessageService();
    this.entityStatsService = new EntityStatsService();
  }

  private readonly populateFields = ['threads', 'tags', 'media', 'creator', 'participants', 'verifiers', 'reactions'];

  private async hydrateEventLocations<T extends Pick<IEvent, 'id'> & Partial<IEvent>>(events: T[]): Promise<T[]> {
    if (events.length === 0) {
      return events;
    }

    const addressMap = await this.addressService.getByEntities(
      EAddressEntityType.Event,
      events.map((event) => event.id),
    );

    return events.map((event) => ({
      ...event,
      location: this.addressService.toLocation(addressMap[event.id]) ?? {},
    }));
  }

  private withResolvedStatus<T extends IEvent | null>(event: T): T {
    if (!event || event.status === EEventStatus.Cancelled) {
      return event;
    }

    return {
      ...event,
      status: deriveEventStatus(event.timings),
    } as T;
  }

  private toEventSummary(event: IEvent): IEventSummary {
    const resolved = this.withResolvedStatus(event) as IEvent;
    return {
      id: resolved.id,
      name: resolved.name,
      status: resolved.status,
      type: resolved.type,
      createdBy: resolved.createdBy,
      location: resolved.location,
      timings: resolved.timings,
      createdAt: resolved.createdAt,
      updatedAt: resolved.updatedAt,
      media: resolved.media,
    };
  }

  private jsonTimestampExpression(field: 'start' | 'end') {
    return `CAST("timings"->>'${field}' AS TIMESTAMPTZ)`;
  }

  private buildDerivedStatusClause(status: EEventStatus) {
    const escape = Event.sequelize!.escape.bind(Event.sequelize);
    const now = escape(new Date().toISOString());
    const startExpr = this.jsonTimestampExpression('start');
    const endExpr = this.jsonTimestampExpression('end');
    const activeStatuses = `COALESCE("status", '') NOT IN (${escape(EEventStatus.Cancelled)}, ${escape(EEventStatus.Draft)})`;

    switch (status) {
      case EEventStatus.Draft:
      case EEventStatus.Cancelled:
        return { status };
      case EEventStatus.Upcoming:
        return Sequelize.literal(`(${activeStatuses} AND ${startExpr} > ${now})`);
      case EEventStatus.Ongoing:
        return Sequelize.literal(`(${activeStatuses} AND ${startExpr} <= ${now} AND ${endExpr} > ${now})`);
      case EEventStatus.Completed:
        return Sequelize.literal(`(${activeStatuses} AND ${endExpr} <= ${now})`);
      default:
        return null;
    }
  }

  private buildWhere(filters: IEventListFilters = {}): WhereOptions {
    const escape = Event.sequelize!.escape.bind(Event.sequelize);
    const clauses: any[] = [];

    if (filters.createdBy) {
      clauses.push({ createdBy: filters.createdBy });
    }

    if (filters.types?.length) {
      clauses.push({ type: { [Op.in]: filters.types } });
    }

    if (filters.statuses?.length) {
      const statusClauses = filters.statuses.map((status) => this.buildDerivedStatusClause(status)).filter(Boolean);
      if (statusClauses.length) {
        clauses.push({ [Op.or]: statusClauses });
      }
    }

    if (filters.tagIds?.length) {
      const tagArray = filters.tagIds.map((tagId) => escape(tagId)).join(', ');
      clauses.push(Sequelize.literal(`(COALESCE("tags", '[]'::jsonb) ?| ARRAY[${tagArray}])`));
    }

    if (filters.startDate && filters.endDate) {
      clauses.push(
        Sequelize.literal(
          `(${this.jsonTimestampExpression('start')} >= ${escape(filters.startDate.toISOString())} AND ${this.jsonTimestampExpression('start')} <= ${escape(filters.endDate.toISOString())})`,
        ),
      );
    }

    if (
      Number.isFinite(filters.latitude) &&
      Number.isFinite(filters.longitude) &&
      Number.isFinite(filters.radiusKm) &&
      (filters.radiusKm ?? 0) > 0
    ) {
      clauses.push(
        this.addressService.buildEntityDistanceClause({
          entityType: EAddressEntityType.Event,
          entityIdColumn: `"Event"."id"`,
          latitude: filters.latitude!,
          longitude: filters.longitude!,
          radiusKm: filters.radiusKm!,
        }),
      );
    }

    if (!clauses.length) {
      return {};
    }

    return { [Op.and]: clauses };
  }

  private async populateEvent(event: IEvent, populate?: boolean | string[]): Promise<IEvent> {
    const promises: Record<string, Promise<any>> = {};
    let fields: string[] = [];

    if (populate) {
      fields =
        populate === true ? this.populateFields : this.populateFields.filter((f) => (populate as string[]).includes(f));
    }

    fields.forEach((field) => {
      switch (field) {
        case 'tags':
          promises.tags = this.tagService.getAllEventTags(event);
          break;
        case 'media':
          promises.media = this.mediaService.getEventMedia(event);
          break;
        case 'creator':
          promises.creator = this.userService.getById(event.createdBy);
          break;
        case 'participants':
          promises.participants = this.userService.getAndPopulateUserProfiles({
            data: event.participants,
            searchKey: 'user',
          });
          break;
        case 'verifiers':
          promises.verifiers = this.userService.getAndPopulateUserProfiles({
            data: event.verifiers,
            searchKey: 'user',
          });
          break;
        case 'reactions':
          promises.reactions = this.reactionService.getReactions(`events/${event.id}`);
          break;
      }
    });

    const results = await Promise.allSettled(Object.values(promises));
    const resolved: Record<string, any> = {};
    Object.keys(promises).forEach((key, index) => {
      const res = results[index];
      resolved[key] = res.status === 'fulfilled' ? res.value : null;
    });

    if (fields.includes('tags')) event.tags = resolved.tags || [];
    if (fields.includes('media')) event.media = resolved.media || [];
    if (fields.includes('creator')) event.creator = resolved.creator || null;
    if (fields.includes('participants')) event.participants = resolved.participants || [];
    if (fields.includes('verifiers')) event.verifiers = resolved.verifiers || [];
    if (fields.includes('reactions')) event.reactions = resolved.reactions || [];

    return this.withResolvedStatus(event) as IEvent;
  }

  async getById(id: string) {
    const cached = await getEventCache(id);
    if (cached) return this.withResolvedStatus(cached as IEvent);

    const data = (await Event.findByPk(id, { raw: true })) as unknown as IEvent | null;
    if (!data) return null;

    const [hydrated] = await this.hydrateEventLocations([data as IEvent]);
    await setEventCache(id, hydrated as IEvent);
    return this.withResolvedStatus(hydrated as IEvent);
  }

  async getEventData(id: string) {
    const event = await this.getById(id);
    if (!event) return null;
    const populatedEvent = await this.populateEvent(event, true);
    return populatedEvent ? this.entityStatsService.hydrateEvent(populatedEvent) : populatedEvent;
  }

  async getEventPreview(id: string) {
    const event = (await Event.findByPk(id, {
      raw: true,
      attributes: ['id', 'name', 'status', 'type', 'createdBy', 'timings', 'media', 'tags'],
    })) as unknown as IEvent | null;
    if (!event) {
      return null;
    }

    const [hydratedEvent] = await this.hydrateEventLocations([event]);
    const preview = await this.populateEvent(hydratedEvent, ['media', 'tags']);
    await this.entityStatsService.hydrateEvent(preview);

    return this.withResolvedStatus(preview);
  }

  async createEvent(body: Partial<IEvent>) {
    if (!body.timings) {
      throw new BadRequestError('Event timings are required');
    }

    body.status = resolveEventStatus(body.timings);
    const result = await validateEventCreate(body, async (data) => {
      const { location, ...rest } = data;
      const row = await Event.sequelize!.transaction(async (transaction) => {
        const created = await Event.create(rest as any, { transaction });
        await this.addressService.replaceAddress(
          EAddressEntityType.Event,
          created.id,
          location,
          transaction,
        );
        return created;
      });
      return (await this.getById(row.id)) as IEvent;
    });
    const eventData = this.withResolvedStatus(result as IEvent) as IEvent;
    if (eventData) {
      await setEventCache(eventData.id, eventData);
      await this.entityStatsService.hydrateEvent(eventData);
    }
    return eventData;
  }

  async update<U extends Partial<IEvent>>({
    existing,
    data,
    populate,
  }: {
    existing: IEvent;
    data: U;
    populate?: boolean | string[];
  }) {
    if (existing && existing.status === EEventStatus.Cancelled) {
      throw new BadRequestError('Cannot update a cancelled event');
    }
    const nextTimings = data.timings ?? existing.timings;
    const nextStatus =
      data.status === EEventStatus.Cancelled ? EEventStatus.Cancelled : resolveEventStatus(nextTimings);

    const result = await validateEventUpdate(data, async (d) => {
      const { location, ...rest } = d;
      await Event.sequelize!.transaction(async (transaction) => {
        const row = await Event.findByPk(existing.id, { transaction });
        if (!row) throw new NotFoundError('Event not found');
        await row.update({
          ...(rest as Partial<IEvent>),
          status: nextStatus,
        } as Partial<IEvent>, { transaction });
        if (location !== undefined) {
          await this.addressService.replaceAddress(
            EAddressEntityType.Event,
            existing.id,
            location,
            transaction,
          );
        }
      });
      return (await this.getById(existing.id)) as IEvent;
    });
    await this.deleteCache(existing.id);
    let eventData = this.withResolvedStatus(result as IEvent) as IEvent;
    const shouldSyncDerivedStats =
      !!eventData && ('participants' in data || 'verifiers' in data || 'media' in data || 'tags' in data);

    if (shouldSyncDerivedStats) {
      await this.entityStatsService.syncEventRowStats(eventData);
    }

    if (populate && eventData) {
      eventData = await this.populateEvent(eventData, populate);
    }
    if (eventData) {
      await this.entityStatsService.hydrateEvent(eventData);
    }
    return eventData;
  }

  private static readonly CLUSTER_ZOOM_THRESHOLD = 12;
  private static readonly MARKERS_PER_TILE_LIMIT = 500;
  private static readonly MAX_CLUSTERS = 200;

  private static gridSizeFromZoom(zoom: number): number {
    if (zoom <= 4) return 5.0;
    if (zoom <= 6) return 2.0;
    if (zoom <= 8) return 0.5;
    if (zoom <= 10) return 0.1;
    return 0.05;
  }

  private async getMatchingEventMarkers(filters: IEventListFilters) {
    const whereClauses: any[] = [
      { entityType: EAddressEntityType.Event },
      Sequelize.literal(`"latitude" IS NOT NULL AND "longitude" IS NOT NULL`),
    ];

    if (
      Number.isFinite(filters.latitude) &&
      Number.isFinite(filters.longitude) &&
      Number.isFinite(filters.radiusKm) &&
      (filters.radiusKm ?? 0) > 0
    ) {
      const escape = Event.sequelize!.escape.bind(Event.sequelize);
      whereClauses.push(
        Sequelize.literal(
          `ST_DWithin(ST_SetSRID(ST_MakePoint("longitude", "latitude"), 4326)::geography, ST_SetSRID(ST_MakePoint(${escape(filters.longitude!)}, ${escape(filters.latitude!)}), 4326)::geography, ${escape(filters.radiusKm! * 1000)})`,
        ),
      );
    }

    const rows = await Address.findAll({
      where: { [Op.and]: whereClauses },
      attributes: ['entityId', 'latitude', 'longitude'],
      raw: true,
      limit: 5000,
    });

    return rows.map((row) => ({
      id: row.entityId,
      name: '',
      latitude: row.latitude as number,
      longitude: row.longitude as number,
    }));
  }

  async getMarkers(
    filters: IEventListFilters = {},
    options: { zoom?: number; tiles?: string[]; flat?: boolean } = {},
  ) {
    const { zoom = 0, tiles, flat = false } = options;
    if (flat) {
      return this.getFlatMarkers(filters);
    }

    const isClusterMode = zoom < EventService.CLUSTER_ZOOM_THRESHOLD;

    if (isClusterMode) {
      return this.getClusterMarkers(filters, zoom);
    }

    return this.getTileMarkers(filters, tiles);
  }

  private async getClusterMarkers(filters: IEventListFilters, zoom: number) {
    const markers = await this.getMatchingEventMarkers(filters);
    const gridSize = EventService.gridSizeFromZoom(zoom);
    const clusters = new Map<string, { latitude: number; longitude: number; count: number }>();

    for (const marker of markers) {
      const snappedLatitude = Math.round(marker.latitude / gridSize) * gridSize;
      const snappedLongitude = Math.round(marker.longitude / gridSize) * gridSize;
      const key = `${snappedLatitude.toFixed(6)}:${snappedLongitude.toFixed(6)}`;
      const existing = clusters.get(key);

      if (!existing) {
        clusters.set(key, {
          latitude: marker.latitude,
          longitude: marker.longitude,
          count: 1,
        });
        continue;
      }

      const nextCount = existing.count + 1;
      existing.latitude = ((existing.latitude * existing.count) + marker.latitude) / nextCount;
      existing.longitude = ((existing.longitude * existing.count) + marker.longitude) / nextCount;
      existing.count = nextCount;
    }

    return {
      mode: 'clusters' as const,
      items: Array.from(clusters.values())
        .sort((a, b) => b.count - a.count)
        .slice(0, EventService.MAX_CLUSTERS),
    };
  }

  private async getTileMarkers(filters: IEventListFilters, tiles?: string[]) {
    if (!tiles?.length) {
      return { mode: 'tiles' as const, items: {} };
    }

    const markers = await this.getMatchingEventMarkers(filters);

    // Distribute rows into tile buckets
    const tileBboxes = tiles.map((tile) => {
      const [minLat, minLng, maxLat, maxLng] = ngeohash.decode_bbox(tile);
      return { tile, minLat, minLng, maxLat, maxLng };
    });

    const tileResults: Record<string, { id: string; name: string; latitude: number; longitude: number }[]> = {};
    for (const tile of tiles) {
      tileResults[tile] = [];
    }

    for (const marker of markers) {
      for (const { tile, minLat, minLng, maxLat, maxLng } of tileBboxes) {
        if (
          marker.latitude >= minLat &&
          marker.latitude <= maxLat &&
          marker.longitude >= minLng &&
          marker.longitude <= maxLng
        ) {
          if (tileResults[tile].length < EventService.MARKERS_PER_TILE_LIMIT) {
            tileResults[tile].push(marker);
          }
          break;
        }
      }
    }

    return {
      mode: 'tiles' as const,
      items: tileResults,
    };
  }

  private async getFlatMarkers(filters: IEventListFilters) {
    const rows = await this.getMatchingEventMarkers(filters);

    return {
      mode: 'flat' as const,
      items: rows,
    };
  }

  async getAll(filters: IEventListFilters = {}, pagination?: Partial<IPaginationParams>): Promise<PaginatedResult<IEventSummary>> {
    const where = this.buildWhere(filters);
    const data = (await findAllWithPagination(
      Event,
      { where },
      pagination,
      'id,name,status,type,createdBy,timings,createdAt,updatedAt,media',
    )) as unknown as PaginatedResult<IEvent>;

    const hydratedItems = await this.hydrateEventLocations(data.items ?? []);

    return {
      ...data,
      items: hydratedItems.map((event) => this.toEventSummary(event as IEvent)),
    };
  }

  async cancel(id: string): Promise<IEvent | null> {
    const row = await Event.findByPk(id);
    if (!row) return null;
    await row.update({ status: EEventStatus.Cancelled } as Partial<IEvent>);
    await this.deleteCache(id);
    return this.getById(id);
  }

  async delete(id: string): Promise<IEvent | null> {
    const existing = await this.getById(id);
    if (!existing) return null;

    const row = await Event.findByPk(id);
    if (!row) return null;

    await Event.sequelize!.transaction(async (transaction) => {
      await this.addressService.replaceAddress(EAddressEntityType.Event, id, null, transaction);
      await row.destroy({ transaction });
    });
    await this.deleteCache(id);
    return existing;
  }

  async getEventUsers(eventId: string, type: 'participants' | 'verifiers', userIds: string[]) {
    const key = `${eventId}:${type}`;
    const cached = await getEventUsersCache(key);
    if (cached) return { users: cached, type, eventId };

    const { items } = await this.userService.getAll(
      { where: { id: userIds } },
      { limit: 1000 },
      'id,name,email,deletedAt',
    );
    const userMap = items?.reduce(
      (acc, user) => {
        acc[user.id] = user;
        return acc;
      },
      {} as Record<string, IBaseUser>,
    );
    await setEventUsersCache(key, userMap);
    return { users: userMap, type, eventId };
  }

  async verifyEvent(
    userId: string,
    eventId: string,
    currentCoordinates: {
      latitude: number;
      longitude: number;
    },
  ) {
    const data = await this.getById(eventId);
    if (!data) throw new NotFoundError('Event not found');
    const { latitude, longitude } = currentCoordinates;
    const { latitude: eventLatitude, longitude: eventLongitude } = data.location;
    const distance = getDistanceInMeters(latitude, longitude, eventLatitude!, eventLongitude!);
    if (distance > 50) {
      throw new BadRequestError(`You are too far from the event. Current distance ${distance.toFixed(2)} meters`);
    }
    const updateData = {
      verifiers: [...data.verifiers],
    };
    const verifierIndex = updateData.verifiers.findIndex((verifier) => verifier.user === userId);
    if (verifierIndex === -1) {
      updateData.verifiers.push({
        user: userId,
        verifiedAt: new Date().toISOString(),
      });
    } else {
      throw new BadRequestError('You are already a verifier');
    }

    await this.update({ existing: data, data: updateData });
    await this.deleteCache(eventId);
    return true;
  }

  async joinLeaveEvent(userId: string, eventId: string, action: 'join' | 'leave') {
    const [event, user] = await Promise.all([this.getById(eventId), this.userService.getById(userId)]);

    if (!event || !user) throw new NotFoundError('Event or user not found');

    const eventData = event;
    const userData = user;

    const resolvedEventStatus =
      eventData.status === EEventStatus.Cancelled ? EEventStatus.Cancelled : deriveEventStatus(eventData.timings);
    if (resolvedEventStatus !== EEventStatus.Ongoing) {
      throw new BadRequestError(`Event is ${resolvedEventStatus}`);
    }

    const updateData = {
      participants: [...eventData.participants],
    };

    if (action === 'join') {
      const existingParticipant = updateData.participants.find(
        (participant) => participant.user === userData.id && participant.status !== EEventParticipantStatus.Declined,
      );
      if (existingParticipant) {
        throw new BadRequestError('User is already a participant');
      }

      const declinedParticipantIndex = updateData.participants.findIndex(
        (participant) => participant.user === userData.id,
      );
      if (declinedParticipantIndex !== -1) {
        updateData.participants[declinedParticipantIndex].status = EEventParticipantStatus.Confirmed;
      } else {
        updateData.participants.push({
          user: userData.id,
          status: EEventParticipantStatus.Confirmed,
        });
      }
    } else if (action === 'leave') {
      const participantIndex = updateData.participants.findIndex((participant) => participant.user === userData.id);

      if (participantIndex === -1) {
        throw new BadRequestError('User is not a participant');
      }

      updateData.participants[participantIndex].status = EEventParticipantStatus.Declined;
    } else {
      throw new BadRequestError('Invalid action');
    }
    await this.update({ existing: event, data: updateData });
    return `Successfully ${action === 'join' ? 'joined' : 'left'} the event`;
  }

  async disassociateMediaFromEvent(eventId: string, mediaId: string) {
    const event = await this.getById(eventId);
    if (!event) throw new NotFoundError('Event not found');
    const media = new Set(event.media as string[]);
    if (!media.has(mediaId)) throw new NotFoundError('Media not found');
    media.delete(mediaId);
    await this.update({
      existing: event,
      data: { media: Array.from(media) } as Partial<IEvent>,
    });
    await this.deleteCache(eventId);
    return true;
  }

  async getThreads(eventId: string, pagination: IPaginationParams) {
    const { items, pagination: threadPagination } = await this.threadService.getAll({ eventId }, pagination);
    const threads = items;
    if (!isEmpty(threads)) {
      await this.entityStatsService.hydrateThreads(threads as IBaseThread[]);
      await Promise.all(
        threads.map(async (t) => {
          const messages = await this.messageService.getAll({ threadId: t.id }, { limit: 1 });
          t.messages = messages.items || [];
        }),
      );
    }
    return { items: threads, pagination: threadPagination };
  }
}

export default EventService;
