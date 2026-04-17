import type { ICustomRequest, IRequestPagination } from '@/definitions/types';
import type { Response } from 'express';
import EventService, { toEventSummary, type IEventListFilters } from './service';
import { BadRequestError, ForbiddenError, NotFoundError } from '@/exceptions';
import { hasMeaningfulChange, isEmpty } from '@/utils';
import TagService from '@/features/tags/service';
import { emitSocketEvent } from '@/socket/emitter';
import { PLATFORM_SOCKET_EVENTS } from '@/constants';
import { getUserRoom } from '@/socket/rooms';
import { EEventStatus, EEventType } from '@/definitions/enums';
import ActivityService from '@/features/activity/service';
import { EActivityEntityType, EActivityType, EActivityVisibility } from '@/features/activity/constants';
import AchievementService from '@/features/achievements/service';
import EntityEngagementService from '@/features/engagement/service';

const eventService = new EventService();
const tagService = new TagService();
const activityService = new ActivityService();
const achievementService = new AchievementService();
const entityEngagementService = new EntityEngagementService();

const getViewerIp = (req: ICustomRequest) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.length > 0) {
    return forwardedFor.split(',')[0].trim();
  }

  return req.socket.remoteAddress || null;
};

function parseEventListFilters(req: ICustomRequest): IEventListFilters {
  const { createdBy, status, type, latitude, longitude, radiusKm, tagIds, datePreset } = req.query;

  let statuses: EEventStatus[] | undefined;
  if (typeof status === 'string' && status.length > 0) {
    statuses = status.split(',').map((item) => item.trim() as EEventStatus);
    if (statuses.some((item) => !Object.values(EEventStatus).includes(item))) {
      throw new BadRequestError('Invalid event status filter');
    }
  }

  let types: EEventType[] | undefined;
  if (typeof type === 'string' && type.length > 0) {
    types = type.split(',').map((item) => item.trim() as EEventType);
    if (types.some((item) => !Object.values(EEventType).includes(item))) {
      throw new BadRequestError('Invalid event type filter');
    }
  }

  const parsedLatitude = typeof latitude === 'string' && latitude.length > 0 ? Number(latitude) : undefined;
  const parsedLongitude = typeof longitude === 'string' && longitude.length > 0 ? Number(longitude) : undefined;
  const parsedRadiusKm = typeof radiusKm === 'string' && radiusKm.length > 0 ? Number(radiusKm) : undefined;

  if (
    (parsedLatitude !== undefined && !Number.isFinite(parsedLatitude)) ||
    (parsedLongitude !== undefined && !Number.isFinite(parsedLongitude)) ||
    (parsedRadiusKm !== undefined && (!Number.isFinite(parsedRadiusKm) || parsedRadiusKm <= 0))
  ) {
    throw new BadRequestError('Invalid location filter');
  }

  let startDate: Date | undefined;
  let endDate: Date | undefined;
  const normalizedDatePreset = typeof datePreset === 'string' ? datePreset.trim().toLowerCase() : null;
  if (normalizedDatePreset && normalizedDatePreset !== 'anytime') {
    const now = new Date();
    if (normalizedDatePreset === 'today') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, -1);
    } else if (normalizedDatePreset === 'this_week') {
      const startOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      startOfWeek.setDate(startOfWeek.getDate() - ((startOfWeek.getDay() + 6) % 7));
      startDate = startOfWeek;
      endDate = new Date(startOfWeek);
      endDate.setDate(endDate.getDate() + 7);
      endDate.setMilliseconds(endDate.getMilliseconds() - 1);
    } else if (normalizedDatePreset === 'this_month') {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
      endDate = new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0, -1);
    } else {
      throw new BadRequestError('Invalid date preset filter');
    }
  }

  return {
    createdBy: typeof createdBy === 'string' && createdBy.length > 0 ? createdBy : undefined,
    statuses,
    types,
    latitude: Number.isFinite(parsedLatitude) && Number.isFinite(parsedLongitude) ? parsedLatitude : undefined,
    longitude: Number.isFinite(parsedLatitude) && Number.isFinite(parsedLongitude) ? parsedLongitude : undefined,
    radiusKm:
      Number.isFinite(parsedLatitude) && Number.isFinite(parsedLongitude) && Number.isFinite(parsedRadiusKm)
        ? parsedRadiusKm
        : undefined,
    tagIds:
      typeof tagIds === 'string' && tagIds.length > 0
        ? tagIds
            .split(',')
            .map((item) => item.trim())
            .filter(Boolean)
        : undefined,
    startDate,
    endDate,
  };
}

export const getEvents = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const filters = parseEventListFilters(req);
  const events = await eventService.getAll(filters, req.pagination);
  return res.status(200).json({ data: events });
};

export const getEventMarkers = async (req: ICustomRequest, res: Response) => {
  const filters = parseEventListFilters(req);
  const { zoom, tiles, flat } = req.query;

  const parsedZoom = typeof zoom === 'string' && zoom.length > 0 ? Number(zoom) : undefined;
  if (parsedZoom !== undefined && (!Number.isFinite(parsedZoom) || parsedZoom < 0 || parsedZoom > 22)) {
    throw new BadRequestError('Invalid zoom level (must be 0–22)');
  }

  const flatMarkers =
    (typeof flat === 'string' && (flat === 'true' || flat === '1')) ||
    (Array.isArray(flat) && flat.some((value) => value === 'true' || value === '1'));

  const parsedTiles =
    typeof tiles === 'string' && tiles.length > 0
      ? tiles
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean)
      : undefined;

  if (parsedTiles && parsedTiles.length > 100) {
    throw new BadRequestError('Too many tiles requested (max 100)');
  }

  if (flatMarkers && (!Number.isFinite(filters.radiusKm) || (filters.radiusKm ?? 0) <= 0)) {
    throw new BadRequestError('radiusKm is required for flat marker requests');
  }

  const result = await eventService.getMarkers(filters, {
    zoom: parsedZoom,
    tiles: parsedTiles,
    flat: flatMarkers,
  });
  return res.status(200).json({ data: result });
};

export const getEventById = async (req: ICustomRequest, res: Response) => {
  const { eventId } = req.params;
  const { view } = req.query;

  const event =
    view === 'preview'
      ? await eventService.getEventPreview(eventId as string)
      : await eventService.getEventData(eventId as string);

  if (isEmpty(event)) throw new NotFoundError('Event not found');

  if (view !== 'preview') {
    await entityEngagementService.trackView('events', eventId as string, {
      userId: req.user.id,
      ip: getViewerIp(req),
      userAgent: req.headers['user-agent'] || null,
    });
  }

  return res.status(200).json({ data: event });
};

export const createEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.createEvent(req.body);
  await Promise.all([
    activityService.create({
      actorId: req.user.id,
      type: EActivityType.EventCreated,
      entityType: EActivityEntityType.Event,
      entityId: event.id,
      payload: {
        eventId: event.id,
        eventName: event.name,
      },
      visibility: EActivityVisibility.Public,
    }),
    achievementService.trackActivity(req.user.id, EActivityType.EventCreated),
  ]);
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_CREATE, { data: toEventSummary(event) });
  return res.status(201).json({ data: event });
};

export const updateEvent = async (req: ICustomRequest, res: Response) => {
  const eventId = req.params.eventId as string;
  const event = await eventService.getById(eventId);
  if (!event) throw new NotFoundError('Event not found');
  if (event.createdBy !== req.user.id) throw new ForbiddenError('You can only update your own events');
  const existingEventData = await eventService.getEventData(eventId);
  const updatedEvent = await eventService.update({
    existing: event,
    data: req.body,
    populate: true,
  });

  if (hasMeaningfulChange(existingEventData, updatedEvent)) {
    emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_UPDATE, {
      data: toEventSummary({ ...updatedEvent, id: eventId }),
    });
  }

  return res.status(200).json({ data: updatedEvent });
};

export const deleteEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.getById(req.params.eventId as string);
  if (!event) throw new NotFoundError('Event not found');
  if (event.createdBy !== req.user.id) throw new ForbiddenError('You can only delete your own events');

  await eventService.delete(req.params.eventId as string);

  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_DELETE, {
    data: { id: req.params.eventId },
  });

  return res.status(200).json({ data: event });
};

export const createEventTag = async (req: ICustomRequest, res: Response) => {
  const { eventId, tagId } = req.params;

  const tag = await tagService.associateTag(eventId as string, tagId as string);
  return res.status(201).json({ data: tag });
};

export const deleteEventTag = async (req: ICustomRequest, res: Response) => {
  const { eventId, tagId } = req.params;

  const tag = await tagService.dissociateTag(eventId as string, tagId as string);
  return res.status(200).json({ data: tag });
};

export const eventJoinLeaveHandler = async (req: ICustomRequest, res: Response) => {
  const eventId = req.params.eventId as string;
  const action = req.params.action as 'join' | 'leave';
  const eventData = await eventService.getById(eventId);
  const previousEvent = await eventService.getEventData(eventId);
  await eventService.joinLeaveEvent(req.user.id, eventId, action);
  const updatedEvent = await eventService.getEventData(eventId);

  const activityType = action === 'join' ? EActivityType.EventJoined : EActivityType.EventLeft;

  const [joinActivity] = await Promise.all([
    activityService.create({
      actorId: req.user.id,
      recipientId: eventData && eventData.createdBy !== req.user.id ? eventData.createdBy : null,
      type: activityType,
      entityType: EActivityEntityType.Event,
      entityId: eventId,
      payload: {
        eventId,
        action,
      },
      visibility: EActivityVisibility.Public,
    }),
    achievementService.trackActivity(req.user.id, activityType),
  ]);
  if (joinActivity.recipientId) {
    emitSocketEvent(
      PLATFORM_SOCKET_EVENTS.ACTIVITY_NEW,
      { data: joinActivity },
      { room: getUserRoom(joinActivity.recipientId) },
    );
  }

  if (updatedEvent && hasMeaningfulChange(previousEvent, updatedEvent)) {
    emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_UPDATE, { data: toEventSummary(updatedEvent) });
  }

  return res.status(200).json({ data: updatedEvent });
};

export const verifyEvent = async (req: ICustomRequest, res: Response) => {
  const { currentCoordinates } = req.body;

  if (isEmpty(currentCoordinates)) throw new BadRequestError('Current coordinates are required');

  const previousEvent = await eventService.getEventData(req.params.eventId as string);
  await eventService.verifyEvent(req.user.id, req.params.eventId as string, currentCoordinates);
  const updatedEvent = await eventService.getEventData(req.params.eventId as string);

  await Promise.all([
    activityService.create({
      actorId: req.user.id,
      type: EActivityType.EventVerified,
      entityType: EActivityEntityType.Event,
      entityId: req.params.eventId as string,
      payload: {
        eventId: req.params.eventId as string,
      },
      visibility: EActivityVisibility.Public,
    }),
    achievementService.trackActivity(req.user.id, EActivityType.EventVerified),
  ]);

  if (updatedEvent && hasMeaningfulChange(previousEvent, updatedEvent)) {
    emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_UPDATE, { data: toEventSummary(updatedEvent) });
  }

  return res.status(200).json({ data: updatedEvent });
};

export const disassociateMediaFromEvent = async (req: ICustomRequest, res: Response) => {
  const { eventId, mediaId } = req.params;

  const event = await eventService.disassociateMediaFromEvent(eventId as string, mediaId as string);
  return res.status(200).json({ data: event });
};

export const deleteEventMedia = async (req: ICustomRequest, res: Response) => {
  const { eventId, mediaId } = req.params;

  const event = await eventService.disassociateMediaFromEvent(eventId as string, mediaId as string);
  return res.status(200).json({ data: event });
};

export const getEventThreads = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const { eventId } = req.params;
  const threads = await eventService.getThreads(eventId as string, req.pagination);

  return res.status(200).json({ data: threads });
};
