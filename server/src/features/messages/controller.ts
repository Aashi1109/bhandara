import { Response } from "express";
import MessageService from "./service";
import { ICustomRequest, IRequestPagination } from "@definitions/types";
import { cleanQueryObject, isEmpty, pick } from "@utils";
import { NotFoundError, ForbiddenError } from "@exceptions";
import { emitSocketEvent } from "@socket/emitter";
import { PLATFORM_SOCKET_EVENTS } from "@constants";
import ThreadsService from "@features/threads/service";

const messagesService = new MessageService();
const threadsService = new ThreadsService();

export const getMessages = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { threadId } = req.params;
  const { userId, parentId } = req.query;

  const _queryObject = { userId, parentId, threadId };

  const messages = await messagesService.getAll(
    cleanQueryObject(_queryObject),
    req.pagination
  );
  return res.status(200).json({
    data: messages,
    error: null,
  });
};

export const createMessage = async (req: ICustomRequest, res: Response) => {
  const { threadId } = req.params;
  
  // Check if the thread (or its parent chain) is locked before creating a message
  const lockStatus = await threadsService.isThreadChainLocked(threadId);
  if (lockStatus.isLocked) {
    throw new ForbiddenError("Cannot add messages to a locked thread or its children");
  }

  const message = await messagesService.create(
    pick({ ...req.body, threadId, isEdited: true }, [
      "userId",
      "content",
      "parentId",
      "threadId",
      "isEdited",
    ]),
    true
  );
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.MESSAGE_CREATED, {
    data: message,
    error: null,
  });
  return res.status(200).json({
    data: message,
    error: null,
  });
};

export const updateMessage = async (req: ICustomRequest, res: Response) => {
  const { messageId } = req.params;
  
  // Get the message to check its thread
  const existingMessage = await messagesService.getById(messageId);
  if (existingMessage && existingMessage.threadId) {
    const lockStatus = await threadsService.isThreadChainLocked(existingMessage.threadId);
    if (lockStatus.isLocked) {
      throw new ForbiddenError("Cannot edit messages in a locked thread or its children");
    }
  }

  const message = await messagesService.update(
    messageId,
    pick({ ...req.body, isEdited: true }, ["content", "isEdited"]),
    true
  );
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.MESSAGE_UPDATED, {
    data: { id: messageId, ...req.body },
    error: null,
  });
  return res.status(200).json({
    data: message,
    error: null,
  });
};

export const deleteMessage = async (req: ICustomRequest, res: Response) => {
  const { messageId } = req.params;
  
  // Get the message to check its thread
  const existingMessage = await messagesService.getById(messageId);
  if (existingMessage && existingMessage.threadId) {
    const lockStatus = await threadsService.isThreadChainLocked(existingMessage.threadId);
    if (lockStatus.isLocked) {
      throw new ForbiddenError("Cannot delete messages in a locked thread or its children");
    }
  }

  const message = await messagesService.delete(messageId);
  emitSocketEvent(PLATFORM_SOCKET_EVENTS.MESSAGE_DELETED, {
    data: { id: messageId },
    error: null,
  });
  return res.status(200).json({
    data: message,
    error: null,
  });
};

export const getMessageById = async (req: ICustomRequest, res: Response) => {
  const { messageId } = req.params;
  const message = await messagesService.getById(messageId, true);
  if (isEmpty(message)) throw new NotFoundError("Message not found");

  return res.status(200).json({
    data: message,
    error: null,
  });
};

export const getChildMessages = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { parentId, threadId } = req.params;
  const messages = await messagesService.getChildren(
    threadId,
    parentId,
    req.pagination
  );
  return res.status(200).json({
    data: messages,
    error: null,
  });
};
