import { Namespace, Server, Socket } from "socket.io";
import config from "@config";
import logger from "@logger";
import { requestContextMiddleware, socketUserParser } from "@middlewares";
import { DefaultEventsMap } from "socket.io/dist/typed-events";
import { IncomingMessage } from "http";
import { IBaseUser } from "@definitions/types";
import { PLATFORM_SOCKET_EVENTS } from "@constants";
import http from "http";
import {
  EventService,
  getSafeUser,
  MediaService,
  MessageService,
  ReactionService,
  ThreadService,
  getExplorePage,
  setExplorePage,
  deleteExplorePage,
  buildExploreSections,
} from "@features";
import { BadRequestError, NotFoundError, ForbiddenError } from "@exceptions";
import { isEmpty } from "@utils";
import { getDistanceInMeters } from "@helpers";
import { setPlatformNamespace, emitSocketEvent } from "./emitter";
import { EAllowedReactionTables } from "@features/reactions/constants";
import { EAccessLevel, EThreadType, EEventStatus } from "@definitions/enums";

interface CustomSocket
  extends Socket<
    DefaultEventsMap,
    DefaultEventsMap,
    DefaultEventsMap,
    IBaseUser
  > {
  request: IncomingMessage & {
    user: IBaseUser;
  };
}

const rooms = new Set();

let platformNamespace: Namespace;

const messageService = new MessageService();
const threadService = new ThreadService();
const mediaService = new MediaService();
const reactionService = new ReactionService();
const eventService = new EventService();

const createJoinRoom = (socket: CustomSocket, room: string) => {
  socket.join(room);
  rooms.add(room);
};

const removeRoom = (room: string) => {
  rooms.delete(room);
};

export function initializeSocket(server: http.Server) {
  const io = new Server(server, { cors: { ...config.corsOptions } });

  platformNamespace = io.of("/platform");
  setPlatformNamespace(platformNamespace);
  platformNamespace.use((socket, next) =>
    requestContextMiddleware(socket.request as any, null, next as any)
  );
  platformNamespace.use(socketUserParser);

  platformNamespace.on(
    PLATFORM_SOCKET_EVENTS.CONNECT,
    async (socket: CustomSocket) => {
      logger.info(`Connected ${socket.id}`);
      const socketUserId = socket.request.user.id;

      socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_CREATED, async (request, cb) => {
        try {
          const messageData = request || {};
          const threadResponse = await threadService.getById(
            messageData.threadId
          );
          if (isEmpty(threadResponse.data))
            throw new NotFoundError("Thread not found");

          const message = await messageService.create(messageData);
          const media = (message.content?.media || []) as string[];

          if (!isEmpty(media)) {
            const mediaData = await mediaService.getMediaByIds(media);
            const populatedMedia = media.map((i) => mediaData.data[i]);
            message.content.media = populatedMedia;
          }

          if (message) {
            (message as any).thread = threadResponse;
            (message as any).user = socket.request.user;
          }
          emitSocketEvent(PLATFORM_SOCKET_EVENTS.MESSAGE_CREATED, {
            data: message,
          });
          cb({ data: true });
        } catch (error) {
          logger.error(`Error sending new message`, error);
          cb?.({
            error: error?.message || "Something went wrong",
            stack: error,
          });
        }
      });

      socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_UPDATED, async (request, cb) => {
        try {
        } catch (error) {
          logger.error(`Error updating message`, error);
          cb?.({ error: error?.message || "Something went wrong" });
        }
      });

      socket.on(PLATFORM_SOCKET_EVENTS.MESSAGE_DELETED, async (request, cb) => {
        logger.debug(`User ${socketUserId} chat window opened`);
        const { conversation: conversationId } = request || {};

        if (!conversationId)
          return cb?.({ error: "Conversation id is required" });
      });

      socket.on(
        PLATFORM_SOCKET_EVENTS.REACTION_CREATED,
        async (request, cb) => {
          try {
            const { contentId, contentPath, reaction, parentId } = request;

            if (!Object.values(EAllowedReactionTables).includes(contentPath)) {
              throw new BadRequestError(
                `Invalid content path provided. Provided:${contentPath}`
              );
            }

            const serviceMap = {
              [EAllowedReactionTables.Message]: messageService,
              [EAllowedReactionTables.Event]: eventService,
              [EAllowedReactionTables.Thread]: threadService,
            };

            const reactionContentId = `${contentPath}/${contentId}`;

            // delete previous reaction from current user on that content
            const responses = await Promise.all([
              serviceMap[contentPath].getById(contentId),
              reactionService.deleteByQuery({
                contentId: reactionContentId,
                userId: socketUserId,
              }),
            ]);

            if (isEmpty(responses[0]))
              throw new NotFoundError(`Reaction or Thread not found`);

            // Check if the content is in a locked thread
            if (contentPath === EAllowedReactionTables.Message) {
              const message = responses[0];
              if (message && message.threadId) {
                const lockStatus = await threadService.isThreadChainLocked(message.threadId);
                if (lockStatus.isLocked) {
                  throw new ForbiddenError("Cannot add reactions to messages in a locked thread");
                }
              }
            } else if (contentPath === EAllowedReactionTables.Thread) {
              const lockStatus = await threadService.isThreadChainLocked(contentId);
              if (lockStatus.isLocked) {
                throw new ForbiddenError("Cannot add reactions to a locked thread");
              }
            }

            const creationData = {
              contentId: reactionContentId,
              emoji: reaction,
              userId: socketUserId,
            };

            const newReaction = await reactionService.create(creationData);

            newReaction.user = getSafeUser(socket.request.user);

            emitSocketEvent(PLATFORM_SOCKET_EVENTS.REACTION_CREATED, {
              data: {
                id: contentId,
                contentPath,
                reaction: newReaction,
                parentId,
              },
            });

            cb?.({ data: true });
          } catch (error) {
            logger.error(`Error sending new message`, error);
            cb?.({
              error: error?.message || "Something went wrong",
              stack: error,
            });
          }
        }
      );
      socket.on(
        PLATFORM_SOCKET_EVENTS.REACTION_UPDATED,
        async (request, cb) => {
          try {
            const { contentId, contentPath, reaction, parentId } = request;

            if (typeof reaction !== "string")
              throw new BadRequestError(`Reaction should be string`);

            if (!Object.values(EAllowedReactionTables).includes(contentPath)) {
              throw new BadRequestError(
                `Invalid content path provided. Provided:${contentPath}`
              );
            }

            const serviceMap = {
              [EAllowedReactionTables.Message]: messageService,
              [EAllowedReactionTables.Event]: eventService,
              [EAllowedReactionTables.Thread]: threadService,
            };

            const reactionContentId = `${contentPath}/${contentId}`;

            // delete previous reaction from current user on that content
            const responses = await Promise.all([
              serviceMap[contentPath].getById(contentId),
              reactionService.getReactions(reactionContentId),
            ]);

            const content = responses[0];

            if (!content)
              throw new NotFoundError(
                `Content not found with provided id:${contentId}`
              );

            // Check if the content is in a locked thread
            if (contentPath === EAllowedReactionTables.Message) {
              if (content && content.threadId) {
                const lockStatus = await threadService.isThreadChainLocked(content.threadId);
                if (lockStatus.isLocked) {
                  throw new ForbiddenError("Cannot update reactions on messages in a locked thread");
                }
              }
            } else if (contentPath === EAllowedReactionTables.Thread) {
              const lockStatus = await threadService.isThreadChainLocked(contentId);
              if (lockStatus.isLocked) {
                throw new ForbiddenError("Cannot update reactions on a locked thread");
              }
            }

            const previousReaction = responses[1]?.[0];

            if (!previousReaction)
              throw new NotFoundError(
                `Reaction not found ${reaction} for user`
              );

            const updatedReaction = await reactionService.update(
              previousReaction.id,
              {
                emoji: reaction,
              }
            );

            updatedReaction.user = getSafeUser(socket.request.user);

            emitSocketEvent(PLATFORM_SOCKET_EVENTS.REACTION_UPDATED, {
              data: {
                id: contentId,
                contentPath,
                reaction: updatedReaction,
                parentId,
              },
            });

            cb?.({ data: true });
          } catch (error) {
            logger.error(`Error sending new message`, error);
            cb?.({
              error: error?.message || "Something went wrong",
              stack: error,
            });
          }
        }
      );
      socket.on(
        PLATFORM_SOCKET_EVENTS.REACTION_DELETED,
        async (request, cb) => {
          try {
            const { contentId, contentPath, id, reaction, parentId } = request;

            if (typeof reaction !== "string")
              throw new BadRequestError(`Reaction should be string`);

            if (!Object.values(EAllowedReactionTables).includes(contentPath)) {
              throw new BadRequestError(
                `Invalid content path provided. Provided:${contentPath}`
              );
            }

            const serviceMap = {
              [EAllowedReactionTables.Message]: messageService,
              [EAllowedReactionTables.Event]: eventService,
              [EAllowedReactionTables.Thread]: threadService,
            };

            const reactionContentId = `${contentPath}/${contentId}`;

            // delete previous reaction from current user on that content
            const responses = await Promise.all([
              serviceMap[contentPath].getById(contentId),
              reactionService.getReactions(reactionContentId),
            ]);

            const content = responses[0];

            if (!content)
              throw new NotFoundError(
                `Content not found with provided id:${contentId}`
              );

            // Check if the content is in a locked thread
            if (contentPath === EAllowedReactionTables.Message) {
              if (content && content.threadId) {
                const lockStatus = await threadService.isThreadChainLocked(content.threadId);
                if (lockStatus.isLocked) {
                  throw new ForbiddenError("Cannot delete reactions on messages in a locked thread");
                }
              }
            } else if (contentPath === EAllowedReactionTables.Thread) {
              const lockStatus = await threadService.isThreadChainLocked(contentId);
              if (lockStatus.isLocked) {
                throw new ForbiddenError("Cannot delete reactions on a locked thread");
              }
            }

            const previousReaction = responses[1]?.[0];

            if (!previousReaction)
              throw new NotFoundError(
                `Reaction not found ${reaction} for user`
              );

            const deletedReaction = await reactionService.delete(
              previousReaction.id,
              true
            );

            emitSocketEvent(PLATFORM_SOCKET_EVENTS.REACTION_DELETED, {
              data: {
                id: contentId,
                contentPath,
                reaction: previousReaction,
                parentId,
              },
            });

            cb?.({ data: true });
          } catch (error) {
            logger.error(`Error sending new message`, error);
            cb?.({
              error: error?.message || "Something went wrong",
              stack: error,
            });
          }
        }
      );

      socket.on(PLATFORM_SOCKET_EVENTS.EXPLORE, async (request, cb) => {
        const { filter: { location } = {} } = request || {};
        const { latitude, longitude } = location || {};
        if (typeof latitude !== "number" || typeof longitude !== "number") {
          return cb?.({ error: "Invalid location" });
        }

        const abortController = new AbortController();
        (socket as any).exploreAbort = abortController;

        try {
          let page = ((await getExplorePage(socketUserId)) || 1) as number;

          while (!abortController.signal.aborted) {
            const { items, pagination } = await eventService.getAll(
              { status: [EEventStatus.Ongoing, EEventStatus.Upcoming] },
              { limit: 10, page }
            );

            let radius = 100;
            let nearby = items;

            while (
              nearby.length === 0 &&
              radius <= 1000 &&
              !abortController.signal.aborted
            ) {
              nearby = items.filter((ev) => {
                const { latitude: elat, longitude: elon } = ev.location || {};
                if (typeof elat !== "number" || typeof elon !== "number")
                  return false;
                return (
                  getDistanceInMeters(latitude, longitude, elat, elon) <= radius
                );
              });
              if (nearby.length === 0) radius += 100;
            }

            if (nearby.length === 0) break;

            const sections = buildExploreSections(nearby);

            for (const section of sections) {
              if (abortController.signal.aborted) break;
              emitSocketEvent(PLATFORM_SOCKET_EVENTS.EXPLORE, {
                data: section,
                error: null,
              });
            }

            await setExplorePage(socketUserId, page);
            page += 1;

            if (!pagination.hasNext) break;
          }
          cb?.({ data: true });
        } catch (err) {
          logger.error("Explore event failed", err);
          cb?.({ error: err?.message || "Something went wrong" });
        }
      });

      socket.on(PLATFORM_SOCKET_EVENTS.THREAD_CREATED, async (request, cb) => {
        try {
          const { eventId, ...messageData } = request || {};

          if (!eventId)
            throw new BadRequestError(`EventId is required for new thread`);

          const eventResponse = await eventService.getById(eventId);

          if (isEmpty(eventResponse))
            throw new NotFoundError("Event not found");

          const newThread = await threadService.create({
            eventId,
            type: EThreadType.Discussion,
            createdBy: socketUserId,
            visibility: EAccessLevel.Public,
          });

          if (isEmpty(newThread))
            throw new Error("Unable able to create thread");

          messageData.threadId = newThread.id;

          const message = await messageService.create(messageData);
          const media = (message.content?.media || []) as string[];

          if (!isEmpty(media)) {
            const mediaData = await mediaService.getMediaByIds(media);
            const populatedMedia = media.map((i) => mediaData.data[i]);
            message.content.media = populatedMedia;
          }

          if (message) {
            (message as any).thread = eventResponse;
            (message as any).user = socket.request.user;
          }

          newThread.messages = [message];
          newThread.creator = socket.request.user;

          emitSocketEvent(PLATFORM_SOCKET_EVENTS.THREAD_CREATED, {
            data: { ...newThread, event: eventResponse },
            error: null,
          });
          cb({ data: true });
        } catch (error) {
          logger.error(`Error sending new message`, error);
          cb?.({
            error: error?.message || "Something went wrong",
            stack: error,
          });
        }
      });

      socket.on(PLATFORM_SOCKET_EVENTS.DISCONNECT, async () => {
        const ctrl = (socket as any).exploreAbort;
        if (ctrl) ctrl.abort();
        await deleteExplorePage(socketUserId);
      });
    }
  );

  return io;
}

export const getPlatformNamespace = () => platformNamespace;
