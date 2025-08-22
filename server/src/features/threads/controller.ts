import { ICustomRequest, IRequestPagination } from "@definitions/types";
import { Response } from "express";
import ThreadsService from "./service";
import { NotFoundError } from "@exceptions";
import { isEmpty } from "@utils";

import { emitSocketEvent } from "@socket/emitter";
import { PLATFORM_SOCKET_EVENTS } from "@constants";
import EventService from "@features/events/service";
import MessageService from "@features/messages/service";

const threadsService = new ThreadsService();
const eventService = new EventService();
const messageService = new MessageService();

export const getThreads = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const threads = await threadsService.getAll({}, req.pagination);
  return res.status(200).json(threads);
};

export const createThread = async (req: ICustomRequest, res: Response) => {
  const thread = await threadsService.create(req.body, true);
  if (thread) {
    const event = await eventService.getById((thread as any).eventId);
    (thread as any).event = event;
  }
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_CREATED, thread);
  return res.status(201).json(thread);
};

export const getThread = async (req: ICustomRequest, res: Response) => {
  const { threadId } = req.params;
  const { includeMessages } = req.query;
  const thread = await threadsService.getById(threadId);
  if (isEmpty(thread)) {
    throw new NotFoundError("Thread not found");
  }

  // parse into boolean or number to get the number of messages to include, default 1 if `includeMessages` is boolean
  const parsedIncludeMessages =
    includeMessages === "true"
      ? 1
      : includeMessages === "false"
      ? 0
      : parseInt(includeMessages as string, 10) || 1;

  if (parsedIncludeMessages) {
    const messages = await messageService.getAll(
      {
        threadId: threadId,
      },
      { limit: parsedIncludeMessages }
    );

    (thread as any).messages = messages.items;
  }

  return res.status(200).json({ data: thread, error: null });
};

export const updateThread = async (req: ICustomRequest, res: Response) => {
  const { threadId } = req.params;
  const thread = await threadsService.update(threadId, req.body, true);
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_UPDATED, {
    data: { id: threadId, ...req.body },
    error: null,
  });
  return res.status(200).json(thread);
};

export const deleteThread = async (req: ICustomRequest, res: Response) => {
  const { threadId } = req.params;
  const thread = await threadsService.delete(threadId);
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_DELETED, {
    data: { id: threadId },
    error: null,
  });
  return res.status(200).json(thread);
};

export const lockThread = async (req: ICustomRequest, res: Response) => {
  const { threadId } = req.params;
  const userId = req.user.id;
  
  const thread = await threadsService.lockThread(threadId, userId);
  
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_LOCKED, {
    data: { 
      id: threadId, 
      lockHistory: thread.lockHistory,
      lockedBy: userId 
    },
    error: null,
  });
  
  return res.status(200).json({
    data: thread,
    error: null,
  });
};

export const unlockThread = async (req: ICustomRequest, res: Response) => {
  const { threadId } = req.params;
  const userId = req.user.id;
  
  const thread = await threadsService.unlockThread(threadId, userId);
  
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_UNLOCKED, {
    data: { 
      id: threadId, 
      lockHistory: thread.lockHistory,
      unlockedBy: userId 
    },
    error: null,
  });
  
  return res.status(200).json({
    data: thread,
    error: null,
  });
};
