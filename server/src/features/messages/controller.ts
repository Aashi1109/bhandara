import type { Response } from 'express';
import MessageService from './service';
import type { ICustomRequest, IRequestPagination } from '@/src/common/definitions/types';
import { cleanQueryObject, hasMeaningfulChange, isEmpty, pick } from '@/src/common/utils';
import { NotFoundError, ForbiddenError } from '@/src/common/exceptions';
import { emitSocketEvent } from '@/src/socket/emitter';
import { PLATFORM_SOCKET_EVENTS } from '@/src/common/constants';
import ThreadsService from '@/src/features/threads/service';
import ActivityService from '@/src/features/activity/service';
import { EActivityType } from '@/src/features/activity/constants';
import AchievementService from '@/src/features/achievements/service';
import EntityEngagementService from '@/src/features/engagement/service';
import { buildMessageActivities } from '@/src/features/activity/chat';
import { getThreadRoom } from '@/src/socket/rooms';

const messagesService = new MessageService();
const threadsService = new ThreadsService();
const activityService = new ActivityService();
const achievementService = new AchievementService();
const entityEngagementService = new EntityEngagementService();
const asString = (value: string | string[] | undefined) => (Array.isArray(value) ? value[0] : value);
const getViewerIp = (req: ICustomRequest) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.length > 0) {
    return forwardedFor.split(',')[0].trim();
  }

  return req.socket.remoteAddress || null;
};

export const getMessages = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const { threadId } = req.params;
  const { userId, parentId } = req.query;

  const _queryObject = { userId, parentId, threadId };

  const messages = await messagesService.getAll(cleanQueryObject(_queryObject), req.pagination);
  return res.status(200).json({
    data: messages,
  });
};

export const createMessage = async (req: ICustomRequest, res: Response) => {
  const threadId = asString(req.params.threadId);
  if (!threadId) throw new NotFoundError('Thread not found');

  const [thread, lockStatus] = await Promise.all([
    threadsService.getById(threadId),
    threadsService.isThreadChainLocked(threadId),
  ]);
  if (!thread) throw new NotFoundError('Thread not found');

  if (lockStatus.isLocked) {
    throw new ForbiddenError('Cannot add messages to a locked thread or its children');
  }

  const message = await messagesService.create(
    pick({ ...req.body, userId: req.user.id, threadId, isEdited: false }, [
      'userId',
      'content',
      'parentId',
      'threadId',
      'isEdited',
    ]),
    true,
  );
  await Promise.all([
    ...buildMessageActivities({
      actorId: req.user.id,
      message,
      threadOwnerId: thread.createdBy,
    }).map((activity) => activityService.create(activity)),
    achievementService.trackActivity(req.user.id, EActivityType.MessageCreated),
  ]);
  emitSocketEvent(
    PLATFORM_SOCKET_EVENTS.MESSAGE_CREATE,
    {
      data: message,
    },
    { room: getThreadRoom(threadId) },
  );
  return res.status(200).json({
    data: message,
  });
};

export const updateMessage = async (req: ICustomRequest, res: Response) => {
  const messageId = asString(req.params.messageId);
  if (!messageId) throw new NotFoundError('Message not found');

  const existingMessage = await messagesService.getById(messageId, true);
  if (!existingMessage) throw new NotFoundError('Message not found');
  if (existingMessage.userId !== req.user.id) {
    throw new ForbiddenError('You can only edit your own messages');
  }

  const lockStatus = await threadsService.isThreadChainLocked(existingMessage.threadId);
  if (lockStatus.isLocked) {
    throw new ForbiddenError('Cannot edit messages in a locked thread or its children');
  }

  const message = await messagesService.update(
    messageId,
    pick({ ...req.body, isEdited: true }, ['content', 'isEdited']),
    true,
  );

  if (hasMeaningfulChange(existingMessage, message)) {
    emitSocketEvent(
      PLATFORM_SOCKET_EVENTS.MESSAGE_UPDATE,
      {
        data: message,
      },
      { room: getThreadRoom(existingMessage.threadId) },
    );
  }

  return res.status(200).json({
    data: message,
  });
};

export const deleteMessage = async (req: ICustomRequest, res: Response) => {
  const messageId = asString(req.params.messageId);
  if (!messageId) throw new NotFoundError('Message not found');

  const existingMessage = await messagesService.getById(messageId);
  if (!existingMessage) throw new NotFoundError('Message not found');
  if (existingMessage.userId !== req.user.id) {
    throw new ForbiddenError('You can only delete your own messages');
  }

  const lockStatus = await threadsService.isThreadChainLocked(existingMessage.threadId);
  if (lockStatus.isLocked) {
    throw new ForbiddenError('Cannot delete messages in a locked thread or its children');
  }

  const message = await messagesService.delete(messageId);
  emitSocketEvent(
    PLATFORM_SOCKET_EVENTS.MESSAGE_DELETE,
    {
      data: { id: messageId, threadId: existingMessage.threadId },
    },
    { room: getThreadRoom(existingMessage.threadId) },
  );
  return res.status(200).json({
    data: message,
  });
};

export const getMessageById = async (req: ICustomRequest, res: Response) => {
  const messageId = asString(req.params.messageId);
  if (!messageId) throw new NotFoundError('Message not found');
  const message = await messagesService.getById(messageId, true);
  if (isEmpty(message)) throw new NotFoundError('Message not found');

  await entityEngagementService.trackView('messages', messageId, {
    userId: req.user.id,
    ip: getViewerIp(req),
    userAgent: req.headers['user-agent'] || null,
  });

  return res.status(200).json({
    data: message,
  });
};

export const getChildMessages = async (req: ICustomRequest & IRequestPagination, res: Response) => {
  const parentId = asString(req.params.parentId);
  const threadId = asString(req.params.threadId);
  if (!parentId || !threadId) throw new NotFoundError('Message not found');
  const messages = await messagesService.getChildren(threadId, parentId, req.pagination);
  return res.status(200).json({
    data: messages,
  });
};
