import { ICustomRequest, IRequestPagination } from "@/definitions/types";
import { Response } from "express";
import EventService from "./service";
import { BadRequestError, NotFoundError } from "@/exceptions";
import { isEmpty } from "@/utils";
import TagService from "@/features/tags/service";
import { emitSocketEvent } from "@/socket/emitter";
import { PLATFORM_SOCKET_EVENTS } from "@/constants";
import { EEventStatus } from "@/definitions/enums";

const eventService = new EventService();
const tagService = new TagService();

export const getEvents = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { createdBy, status } = req.query;
  const where: Record<string, any> = {};
  if (createdBy) where.createdBy = createdBy;
  if (status) {
    const statuses = (status as string)
      .split(",")
      .filter((s) => Object.values(EEventStatus).includes(s as EEventStatus));
    if (statuses.length) where.status = statuses;
  }
  const events = await eventService.getAll(where, req.pagination);
  return res.status(200).json({ data: events, error: null });
};

export const getEventById = async (req: ICustomRequest, res: Response) => {
  const { eventId } = req.params;

  const event = await eventService.getEventData(eventId);

  if (isEmpty(event)) throw new NotFoundError("Event not found");

  return res.status(200).json({ data: event, error: null });
};

export const createEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.createEvent(req.body);
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_CREATED, { data: event });
  return res.status(201).json({ data: event, error: null });
};

export const updateEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.getById(req.params.eventId);
  const updatedEvent = await eventService.update({
    existing: event,
    data: req.body,
    populate: true,
  });
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_UPDATED, {
    data: { id: req.params.id, ...updatedEvent },
    error: null,
  });
  return res.status(200).json({ data: event, error: null });
};

export const deleteEvent = async (req: ICustomRequest, res: Response) => {
  const event = await eventService.delete(req.params.id);

  if (isEmpty(event)) throw new NotFoundError("Event not found");

  emitSocketEvent(PLATFORM_SOCKET_EVENTS.EVENT_DELETED, {
    data: { id: req.params.id },
    error: null,
  });

  return res.status(200).json({ data: event, error: null });
};

export const createEventTag = async (req: ICustomRequest, res: Response) => {
  const { eventId, tagId } = req.params;

  const tag = await tagService.dissociateTag(eventId, tagId);
  return res.status(201).json({ data: tag, error: null });
};

export const deleteEventTag = async (req: ICustomRequest, res: Response) => {
  const { eventId, tagId } = req.params;

  const tag = await tagService.dissociateTag(eventId, tagId);
  return res.status(200).json({ data: tag, error: null });
};

export const eventJoinLeaveHandler = async (
  req: ICustomRequest,
  res: Response
) => {
  const event = await eventService.joinLeaveEvent(
    req.user.id,
    req.params.eventId,
    req.params.action as "join" | "leave"
  );
  return res.status(200).json({ data: event, error: null });
};

export const verifyEvent = async (req: ICustomRequest, res: Response) => {
  const { currentCoordinates } = req.body;

  if (isEmpty(currentCoordinates))
    throw new BadRequestError("Current coordinates are required");

  const event = await eventService.verifyEvent(
    req.user.id,
    req.params.eventId,
    currentCoordinates
  );
  return res.status(200).json({ data: event, error: null });
};

export const disassociateMediaFromEvent = async (
  req: ICustomRequest,
  res: Response
) => {
  const { eventId, mediaId } = req.params;

  const event = await eventService.disassociateMediaFromEvent(eventId, mediaId);
  return res.status(200).json({ data: event, error: null });
};

export const deleteEventMedia = async (req: ICustomRequest, res: Response) => {
  const { eventId, mediaId } = req.params;

  const event = await eventService.disassociateMediaFromEvent(eventId, mediaId);
  return res.status(200).json({ data: event, error: null });
};

export const getEventThreads = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { eventId } = req.params;
  const threads = await eventService.getThreads(eventId, req.pagination);

  return res.status(200).json({ data: threads, error: null });
};
