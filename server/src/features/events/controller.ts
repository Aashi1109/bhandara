import type { ICustomRequest, IRequestPagination } from '@/definitions/types';
import type { Response } from 'express';
import EventService from './service';
import { BadRequestError, NotFoundError } from '@/exceptions';
import { isEmpty } from '@/utils';
import TagService from '@/features/tags/service';
import { emitSocketEvent } from '@/socket/emitter';
import { PLATFORM_SOCKET_EVENTS } from '@/constants';
import { EEventStatus } from '@/definitions/enums';
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

export const getEvents = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const { createdBy, status } = req.query;
  const where: Record<string, any> = {};
  if (createdBy) where.createdBy = createdBy;
  if (status) {
    const statuses = (status as string)
      .split(',')
      .filter((s) => Object.values(EEventStatus).includes(s as EEventStatus));
    if (statuses.length) where.status = statuses;
  }
  const events = await eventService.getAll(where, req.pagination);
  return res.status(200).json({ data: events });
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
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_CREATED, { data: event });
  return res.status(201).json({ data: event });
};

export const updateEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.getById(req.params.eventId as string);
  const updatedEvent = await eventService.update({
    existing: event,
    data: req.body,
    populate: true,
  });
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_UPDATED, {
    data: { id: req.params.id, ...updatedEvent },
    });
  return res.status(200).json({ data: event });
};

export const deleteEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.delete(req.params.eventId as string);

  if (isEmpty(event)) throw new NotFoundError('Event not found');

  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_DELETED, {
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
  const result = await eventService.joinLeaveEvent(req.user.id, eventId, action);

  const activityType = action === 'join' ? EActivityType.EventJoined : EActivityType.EventLeft;

  await Promise.all([
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

  return res.status(200).json({ data: result });
};

export const verifyEvent = async (req: ICustomRequest, res: Response) => {
  const { currentCoordinates } = req.body;

  if (isEmpty(currentCoordinates)) throw new BadRequestError('Current coordinates are required');

  const event = await eventService.verifyEvent(req.user.id, req.params.eventId as string, currentCoordinates);

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

  return res.status(200).json({ data: event });
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
