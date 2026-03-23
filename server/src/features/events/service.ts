import type { IBaseThread, IBaseUser, IEvent, IPaginationParams } from '@/definitions/types';
import ThreadsService from '../threads/service';
import { findAllWithPagination } from '@/utils/dbUtils';
import { Op } from 'sequelize';
import { EEventParticipantStatus, EEventStatus } from '@/definitions/enums';
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

class EventService {
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
    this.threadService = new ThreadsService();
    this.tagService = new TagService();
    this.mediaService = new MediaService();
    this.userService = new UserService();
    this.reactionService = new ReactionService();
    this.messageService = new MessageService();
    this.entityStatsService = new EntityStatsService();
  }

  private readonly populateFields = ['threads', 'tags', 'media', 'creator', 'participants', 'verifiers', 'reactions'];

  private withResolvedStatus<T extends IEvent | null>(event: T): T {
    if (!event || event.status === EEventStatus.Cancelled) {
      return event;
    }

    return {
      ...event,
      status: deriveEventStatus(event.timings),
    } as T;
  }

  private toEventSummary(event: IEvent) {
    const resolved = this.withResolvedStatus(event) as IEvent;
    return {
      id: resolved.id,
      name: resolved.name,
      status: resolved.status,
      type: resolved.type,
      createdBy: resolved.createdBy,
      location: resolved.location,
      timings: resolved.timings,
    };
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

    const data = await Event.findByPk(id, { raw: true });
    if (!data) return null;

    await setEventCache(id, data as IEvent);
    return this.withResolvedStatus(data as IEvent);
  }

  async getEventData(id: string) {
    const event = await this.getById(id);
    const populatedEvent = await this.populateEvent(event, true);
    return populatedEvent ? this.entityStatsService.hydrateEvent(populatedEvent) : populatedEvent;
  }

  async getEventPreview(id: string) {
    const event = (await Event.findByPk(id, {
      raw: true,
      attributes: ['id', 'name', 'status', 'type', 'createdBy', 'location', 'timings', 'media', 'tags'],
    })) as IEvent | null;
    if (!event) {
      return null;
    }

    const preview = await this.populateEvent(event, ['media', 'tags']);
    await this.entityStatsService.hydrateEvent(preview);

    return this.withResolvedStatus(preview);
  }

  async createEvent(body: Partial<IEvent>) {
    if (!body.timings) {
      throw new BadRequestError('Event timings are required');
    }

    body.status = resolveEventStatus(body.timings);
    const result = await validateEventCreate(body, async (data) => {
      const row = await Event.create(data as Partial<IEvent>);
      return row.toJSON() as IEvent;
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
      const row = await Event.findByPk(existing.id);
      if (!row) throw new NotFoundError('Event not found');
      await row.update({
        ...(d as Partial<IEvent>),
        status: nextStatus,
      } as Partial<IEvent>);
      return row.toJSON() as IEvent;
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

  async getAll(where: Record<string, any> = {}, pagination?: Partial<IPaginationParams>) {
    if (Array.isArray(where.status)) {
      where.status = { [Op.in]: where.status };
    }

    const data = await findAllWithPagination(
      Event,
      { where },
      pagination,
      'id,name,status,type,createdBy,location,timings',
    );
    if (data.items) {
      data.items = data.items.map((event) => this.toEventSummary(event as IEvent)) as typeof data.items;
    }
    return data;
  }

  async cancel(id: string): Promise<IEvent | null> {
    const row = await Event.findByPk(id);
    if (!row) return null;
    await row.update({ status: EEventStatus.Cancelled } as Partial<IEvent>);
    await this.deleteCache(id);
    return row.toJSON() as IEvent;
  }

  async delete(id: string): Promise<IEvent | null> {
    const row = await Event.findByPk(id);
    if (!row) return null;
    await row.destroy();
    await this.deleteCache(id);
    return row.toJSON() as IEvent;
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
    const { latitude, longitude } = currentCoordinates;
    const { latitude: eventLatitude, longitude: eventLongitude } = data.location;
    const distance = getDistanceInMeters(latitude, longitude, eventLatitude, eventLongitude);
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
