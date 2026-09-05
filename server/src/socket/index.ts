import { type Namespace, type Socket, Server, type DefaultEventsMap } from 'socket.io';
import {
  config,
  logger,
  type IBaseUser,
  PLATFORM_SOCKET_EVENTS,
  BadRequestError,
  NotFoundError,
  ForbiddenError,
  hasMeaningfulChange,
  isEmpty,
  EAccessLevel,
} from '@/common';
import type { IncomingMessage } from 'http';
import type http from 'http';

import { toUserMini } from '@/features/users/service';

import { setPlatformNamespace, emitSocketEvent } from './emitter';
import { EAllowedReactionTables } from '@/features/reactions/constants';
import ActivityService from '@/features/activity/service';
import { EActivityType } from '@/features/activity/constants';
import AchievementService from '@/features/achievements/service';
import { buildMessageActivities } from '@/features/activity/chat';
import { getThreadRoom, getUserRoom } from './rooms';
import { EventService, MessageService, ReactionService, ThreadService } from '../features';
import { requestContextMiddleware, socketUserParser } from '@app/server/middlewares';

interface CustomSocket extends Socket<DefaultEventsMap, DefaultEventsMap, DefaultEventsMap, IBaseUser> {
  request: IncomingMessage & {
    user: IBaseUser;
  };
}

const rooms = new Set();

let platformNamespace: Namespace;

const messageService = new MessageService();
const threadService = new ThreadService();
const reactionService = new ReactionService();
const eventService = new EventService();
const activityService = new ActivityService();
const achievementService = new AchievementService();

const createJoinRoom = (socket: CustomSocket, room: string) => {
  socket.join(room);
  rooms.add(room);
};

const removeRoom = (room: string) => {
  rooms.delete(room);
};

export function initializeSocket(server: http.Server) {
  const io = new Server(server, { cors: { ...config.corsOptions } });

  platformNamespace = io.of('/platform');
  setPlatformNamespace(platformNamespace);
  platformNamespace.use((socket, next) => requestContextMiddleware(socket.request as any, null as any, next as any));
  platformNamespace.use(socketUserParser);

  platformNamespace.on(PLATFORM_SOCKET_EVENTS.CONNECT, async (socket: CustomSocket) => {
    logger.info(`Connected ${socket.id}`);
    const socketUserId = socket.request.user.id;
    socket.join(getUserRoom(socketUserId));

    socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_CREATE, async (request, _, cb) => {
      try {
        const messageData = {
          ...(request || {}),
          isEdited: false,
          userId: socketUserId,
        };
        const threadResponse = await threadService.getById(messageData.threadId);
        if (isEmpty(threadResponse)) throw new NotFoundError('Thread not found');

        const lockStatus = await threadService.isThreadChainLocked(messageData.threadId);
        if (lockStatus.isLocked) {
          throw new ForbiddenError('Cannot add messages to a locked thread or its children');
        }

        const message = await messageService.create(messageData, true);
        const activityData = buildMessageActivities({
          actorId: socketUserId,
          message,
          threadOwnerId: threadResponse.createdBy,
        });
        const [createdActivities] = await Promise.all([
          Promise.all(activityData.map((a) => activityService.create(a))),
          achievementService.trackActivity(socketUserId, EActivityType.MessageCreated),
        ]);
        for (const activity of createdActivities) {
          if (activity.recipientId) {
            emitSocketEvent(
              PLATFORM_SOCKET_EVENTS.ACTIVITY_NEW,
              { data: activity },
              { room: getUserRoom(activity.recipientId) },
            );
          }
        }
        emitSocketEvent(
          PLATFORM_SOCKET_EVENTS.MESSAGE_CREATE,
          {
            data: message,
          },
          { room: getThreadRoom(message.threadId) },
        );
        cb?.({ data: message });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error sending new message`, error);
        cb?.({
          error: errorMessage,
          stack: error,
        });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_UPDATE, async (request, cb) => {
      try {
        const { id, content } = request || {};

        if (typeof id !== 'string' || id.trim().length === 0) {
          throw new BadRequestError('Message id is required');
        }

        const existingMessage = await messageService.getById(id, true);
        if (!existingMessage) {
          throw new NotFoundError('Message not found');
        }

        if (existingMessage.userId !== socketUserId) {
          throw new ForbiddenError('You can only edit your own messages');
        }

        const lockStatus = await threadService.isThreadChainLocked(existingMessage.threadId);
        if (lockStatus.isLocked) {
          throw new ForbiddenError('Cannot edit messages in a locked thread or its children');
        }

        const updatedMessage = await messageService.update(
          id,
          {
            content,
            isEdited: true,
          },
          true,
        );

        if (hasMeaningfulChange(existingMessage, updatedMessage)) {
          emitSocketEvent(
            PLATFORM_SOCKET_EVENTS.MESSAGE_UPDATE,
            {
              data: updatedMessage,
            },
            { room: getThreadRoom(existingMessage.threadId) },
          );
        }

        cb?.({ data: updatedMessage });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error updating message`, error);
        cb?.({ error: errorMessage });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_DELETE, async (request, cb) => {
      try {
        const { id } = request || {};

        if (typeof id !== 'string' || id.trim().length === 0) {
          throw new BadRequestError('Message id is required');
        }

        const existingMessage = await messageService.getById(id);
        if (!existingMessage) {
          throw new NotFoundError('Message not found');
        }

        if (existingMessage.userId !== socketUserId) {
          throw new ForbiddenError('You can only delete your own messages');
        }

        const lockStatus = await threadService.isThreadChainLocked(existingMessage.threadId);
        if (lockStatus.isLocked) {
          throw new ForbiddenError('Cannot delete messages in a locked thread or its children');
        }

        await messageService.delete(id);

        const payload = { id, threadId: existingMessage.threadId };
        emitSocketEvent(
          PLATFORM_SOCKET_EVENTS.MESSAGE_DELETE,
          {
            data: payload,
          },
          { room: getThreadRoom(existingMessage.threadId) },
        );

        cb?.({ data: payload });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error deleting message`, error);
        cb?.({ error: errorMessage });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.JOIN_ROOM, async (request, cb) => {
      try {
        const room = request?.room;
        if (typeof room !== 'string' || room.trim().length === 0) {
          throw new BadRequestError('Room is required');
        }

        const trimmedRoom = room.trim();
        if (trimmedRoom.startsWith('thread:')) {
          const threadId = trimmedRoom.replace('thread:', '');
          const thread = await threadService.getById(threadId);
          if (!thread) throw new NotFoundError('Thread not found');
        }

        createJoinRoom(socket, trimmedRoom);
        cb?.({ data: true });
      } catch (error) {
        cb?.({ error: error instanceof Error ? error.message : 'Something went wrong' });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.LEAVE_ROOM, async (request, cb) => {
      try {
        const room = request?.room;
        if (typeof room !== 'string' || room.trim().length === 0) {
          throw new BadRequestError('Room is required');
        }

        const trimmedRoom = room.trim();
        socket.leave(trimmedRoom);
        removeRoom(trimmedRoom);
        cb?.({ data: true });
      } catch (error) {
        cb?.({ error: error instanceof Error ? error.message : 'Something went wrong' });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.REACTION_CREATE, async (request, cb) => {
      try {
        const { contentId, contentPath, reaction, parentId } = request;

        if (!Object.values(EAllowedReactionTables).includes(contentPath)) {
          throw new BadRequestError(`Invalid content path provided. Provided:${contentPath}`);
        }

        const targetPath = contentPath as EAllowedReactionTables;
        const serviceMap = {
          [EAllowedReactionTables.Message]: messageService,
          [EAllowedReactionTables.Event]: eventService,
          [EAllowedReactionTables.Thread]: threadService,
        };

        const reactionContentId = `${contentPath}/${contentId}`;

        // delete previous reaction from current user on that content
        const responses = await Promise.all([
          serviceMap[targetPath].getById(contentId),
          reactionService.deleteByQuery({
            contentId: reactionContentId,
            userId: socketUserId,
          }),
        ]);

        if (isEmpty(responses[0])) throw new NotFoundError(`Reaction or Thread not found`);

        // Check if the content is in a locked thread
        if (contentPath === EAllowedReactionTables.Message) {
          const message = responses[0];
          if (message && message.threadId) {
            const lockStatus = await threadService.isThreadChainLocked(message.threadId);
            if (lockStatus.isLocked) {
              throw new ForbiddenError('Cannot add reactions to messages in a locked thread');
            }
          }
        } else if (contentPath === EAllowedReactionTables.Thread) {
          const lockStatus = await threadService.isThreadChainLocked(contentId);
          if (lockStatus.isLocked) {
            throw new ForbiddenError('Cannot add reactions to a locked thread');
          }
        }

        const creationData = {
          contentId: reactionContentId,
          emoji: reaction,
          userId: socketUserId,
        };

        const newReaction = await reactionService.create(creationData);

        newReaction.user = toUserMini(socket.request.user) as unknown as IBaseUser;

        const threadId =
          contentPath === EAllowedReactionTables.Message
            ? responses[0]?.threadId
            : contentPath === EAllowedReactionTables.Thread
              ? String(contentId)
              : undefined;

        await achievementService.trackActivity(socketUserId, EActivityType.ReactionCreated);

        emitSocketEvent(
          PLATFORM_SOCKET_EVENTS.REACTION_CREATE,
          {
            data: {
              id: contentId,
              contentPath,
              reaction: newReaction,
              parentId,
              threadId,
            },
          },
          threadId ? { room: getThreadRoom(threadId) } : undefined,
        );

        cb?.({ data: true });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error sending new message`, error);
        cb?.({
          error: errorMessage,
          stack: error,
        });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.REACTION_UPDATE, async (request, cb) => {
      try {
        const { contentId, contentPath, reaction, parentId } = request;

        if (typeof reaction !== 'string') throw new BadRequestError(`Reaction should be string`);

        if (!Object.values(EAllowedReactionTables).includes(contentPath)) {
          throw new BadRequestError(`Invalid content path provided. Provided:${contentPath}`);
        }

        const targetPath = contentPath as EAllowedReactionTables;
        const serviceMap = {
          [EAllowedReactionTables.Message]: messageService,
          [EAllowedReactionTables.Event]: eventService,
          [EAllowedReactionTables.Thread]: threadService,
        };

        const reactionContentId = `${contentPath}/${contentId}`;

        // delete previous reaction from current user on that content
        const responses = await Promise.all([
          serviceMap[targetPath].getById(contentId),
          reactionService.getReactions(reactionContentId),
        ]);

        const content = responses[0];

        if (!content) throw new NotFoundError(`Content not found with provided id:${contentId}`);

        // Check if the content is in a locked thread
        if (contentPath === EAllowedReactionTables.Message) {
          if (content && content.threadId) {
            const lockStatus = await threadService.isThreadChainLocked(content.threadId);
            if (lockStatus.isLocked) {
              throw new ForbiddenError('Cannot update reactions on messages in a locked thread');
            }
          }
        } else if (contentPath === EAllowedReactionTables.Thread) {
          const lockStatus = await threadService.isThreadChainLocked(contentId);
          if (lockStatus.isLocked) {
            throw new ForbiddenError('Cannot update reactions on a locked thread');
          }
        }

        const previousReaction = responses[1]?.[0];

        if (!previousReaction) throw new NotFoundError(`Reaction not found ${reaction} for user`);

        const updatedReaction = await reactionService.update(previousReaction.id, {
          emoji: reaction,
        });

        const shouldEmitReactionUpdate = hasMeaningfulChange(previousReaction, updatedReaction);
        updatedReaction.user = toUserMini(socket.request.user) as unknown as IBaseUser;

        const threadId =
          contentPath === EAllowedReactionTables.Message
            ? content?.threadId
            : contentPath === EAllowedReactionTables.Thread
              ? String(contentId)
              : undefined;

        if (shouldEmitReactionUpdate) {
          emitSocketEvent(
            PLATFORM_SOCKET_EVENTS.REACTION_UPDATE,
            {
              data: {
                id: contentId,
                contentPath,
                reaction: updatedReaction,
                parentId,
                threadId,
              },
            },
            threadId ? { room: getThreadRoom(threadId) } : undefined,
          );
        }

        cb?.({ data: true });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error sending new message`, error);
        cb?.({
          error: errorMessage,
          stack: error,
        });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.REACTION_DELETE, async (request, cb) => {
      try {
        const { contentId, contentPath, id, reaction, parentId } = request;

        if (typeof reaction !== 'string') throw new BadRequestError(`Reaction should be string`);

        if (!Object.values(EAllowedReactionTables).includes(contentPath)) {
          throw new BadRequestError(`Invalid content path provided. Provided:${contentPath}`);
        }

        const targetPath = contentPath as EAllowedReactionTables;
        const serviceMap = {
          [EAllowedReactionTables.Message]: messageService,
          [EAllowedReactionTables.Event]: eventService,
          [EAllowedReactionTables.Thread]: threadService,
        };

        const reactionContentId = `${contentPath}/${contentId}`;

        // delete previous reaction from current user on that content
        const responses = await Promise.all([
          serviceMap[targetPath].getById(contentId),
          reactionService.getReactions(reactionContentId),
        ]);

        const content = responses[0];

        if (!content) throw new NotFoundError(`Content not found with provided id:${contentId}`);

        // Check if the content is in a locked thread
        if (contentPath === EAllowedReactionTables.Message) {
          if (content && content.threadId) {
            const lockStatus = await threadService.isThreadChainLocked(content.threadId);
            if (lockStatus.isLocked) {
              throw new ForbiddenError('Cannot delete reactions on messages in a locked thread');
            }
          }
        } else if (contentPath === EAllowedReactionTables.Thread) {
          const lockStatus = await threadService.isThreadChainLocked(contentId);
          if (lockStatus.isLocked) {
            throw new ForbiddenError('Cannot delete reactions on a locked thread');
          }
        }

        const previousReaction = responses[1]?.[0];

        if (!previousReaction) throw new NotFoundError(`Reaction not found ${reaction} for user`);

        const deletedReaction = await reactionService.delete(previousReaction.id);

        const threadId =
          contentPath === EAllowedReactionTables.Message
            ? content?.threadId
            : contentPath === EAllowedReactionTables.Thread
              ? String(contentId)
              : undefined;

        emitSocketEvent(
          PLATFORM_SOCKET_EVENTS.REACTION_DELETE,
          {
            data: {
              id: contentId,
              contentPath,
              reaction: previousReaction,
              parentId,
              threadId,
            },
          },
          threadId ? { room: getThreadRoom(threadId) } : undefined,
        );

        cb?.({ data: true });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error sending new message`, error);
        cb?.({
          error: errorMessage,
          stack: error,
        });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_CREATE, async (request, cb) => {
      try {
        const { eventId, ...messageData } = request || {};

        if (!eventId) throw new BadRequestError(`EventId is required for new thread`);

        const eventResponse = await eventService.getById(eventId);

        if (isEmpty(eventResponse) || !(await eventService.canView(eventResponse!, socketUserId)))
          throw new NotFoundError('Event not found');

        const newThread = await threadService.create({
          eventId,
          createdBy: socketUserId,
          visibility: EAccessLevel.Public,
        });

        if (isEmpty(newThread)) throw new Error('Unable able to create thread');

        messageData.threadId = newThread.id;

        const message = await messageService.create(messageData, true);

        newThread.messages = [message];
        newThread.creator = socket.request.user;

        emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_CREATE, {
          data: { ...newThread, event: { id: eventResponse!.id, name: eventResponse!.name } },
        });
        cb({ data: true });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Something went wrong';
        logger.error(`Error sending new message`, error);
        cb?.({
          error: errorMessage,
          stack: error,
        });
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.DISCONNECT, async () => {});
  });

  return io;
}

export const getPlatformNamespace = () => platformNamespace;
