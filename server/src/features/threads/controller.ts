import type { ICustomRequest, IRequestPagination } from '@/definitions/types';
import type { Response } from 'express';
import ThreadsService from './service';
import { NotFoundError } from '@/exceptions';
import { hasMeaningfulChange, isEmpty } from '@/utils';

import { emitSocketEvent } from '@/socket/emitter';
import { PLATFORM_SOCKET_EVENTS } from '@/constants';
import EventService from '@/features/events/service';
import MessageService from '@/features/messages/service';
import EntityEngagementService from '@/features/engagement/service';
import { getThreadRoom } from '@/socket/rooms';

const threadsService = new ThreadsService();
const eventService = new EventService();
const messageService = new MessageService();
const entityEngagementService = new EntityEngagementService();
const asString = (value: string | string[] | undefined) => (Array.isArray(value) ? value[0] : value);
const getViewerIp = (req: ICustomRequest) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.length > 0) {
    return forwardedFor.split(',')[0].trim();
  }

  return req.socket.remoteAddress || null;
};

export const getThreads = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const threads = await threadsService.getAll({}, req.pagination);
  return res.status(200).json({ data: threads });
};

export const createThread = async (req: ICustomRequest, res: Response) => {
  const user = req.user;
  const thread = await threadsService.create({ ...req.body, createdBy: user.id }, true);
  if (thread) {
    const event = await eventService.getById((thread as any).eventId);
    (thread as any).event = event ? { id: event.id, name: event.name } : null;
  }
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_CREATE, { data: thread });
  return res.status(201).json({ data: thread });
};

export const getThread = async (req: ICustomRequest, res: Response) => {
  const threadId = asString(req.params.threadId);
  if (!threadId) throw new NotFoundError('Thread not found');
  const { includeMessages } = req.query;
  const thread = await threadsService.getById(threadId);
  if (isEmpty(thread)) {
    throw new NotFoundError('Thread not found');
  }

  await entityEngagementService.trackView('threads', threadId, {
    userId: req.user.id,
    ip: getViewerIp(req),
    userAgent: req.headers['user-agent'] || null,
  });

  // parse into boolean or number to get the number of messages to include, default 1 if `includeMessages` is boolean
  const parsedIncludeMessages =
    includeMessages === 'true' ? 1 : includeMessages === 'false' ? 0 : parseInt(includeMessages as string, 10) || 1;

  if (parsedIncludeMessages) {
    const messages = await messageService.getAll(
      {
        threadId,
      },
      { limit: parsedIncludeMessages },
    );

    (thread as any).messages = messages.items;
  }

  return res.status(200).json({ data: thread });
};

export const updateThread = async (req: ICustomRequest, res: Response) => {
  const threadId = asString(req.params.threadId);
  if (!threadId) throw new NotFoundError('Thread not found');
  const existingThread = await threadsService.getById(threadId);
  if (isEmpty(existingThread)) throw new NotFoundError('Thread not found');
  const thread = await threadsService.update(threadId, req.body, true);

  if (hasMeaningfulChange(existingThread, thread)) {
    emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_UPDATE, {
      data: { id: threadId, ...req.body },
    });
  }

  return res.status(200).json({ data: thread });
};

export const deleteThread = async (req: ICustomRequest, res: Response) => {
  const threadId = asString(req.params.threadId);
  if (!threadId) throw new NotFoundError('Thread not found');
  const thread = await threadsService.delete(threadId);
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_DELETE, {
    data: { id: threadId },
  });
  return res.status(200).json({ data: thread });
};

export const lockThread = async (req: ICustomRequest, res: Response) => {
  const threadId = asString(req.params.threadId);
  if (!threadId) throw new NotFoundError('Thread not found');
  const userId = req.user.id;

  const thread = await threadsService.lockThread(threadId, userId);

  emitSocketEvent(
    PLATFORM_SOCKET_EVENTS.THREAD_LOCK,
    {
      data: {
        id: threadId,
        lockHistory: thread.lockHistory,
        lockedBy: userId,
      },
    },
    { room: getThreadRoom(threadId) },
  );

  return res.status(200).json({
    data: thread,
  });
};

export const unlockThread = async (req: ICustomRequest, res: Response) => {
  const threadId = asString(req.params.threadId);
  if (!threadId) throw new NotFoundError('Thread not found');
  const userId = req.user.id;

  const thread = await threadsService.unlockThread(threadId, userId);

  emitSocketEvent(
    PLATFORM_SOCKET_EVENTS.THREAD_UNLOCK,
    {
      data: {
        id: threadId,
        lockHistory: thread.lockHistory,
        unlockedBy: userId,
      },
    },
    { room: getThreadRoom(threadId) },
  );

  return res.status(200).json({
    data: thread,
  });
};
