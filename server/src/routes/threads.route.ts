/**
 * @openapi
 * components:
 *   schemas:
 *     Thread:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         eventId:
 *           type: string
 *         type:
 *           type: string
 *     Message:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         content:
 *           type: object
 */
import { Router } from "express";
import {
  asyncHandler,
  paginationParser,
  sessionParser,
  userParser,
} from "@middlewares";

import {
  getMessages,
  createMessage,
  getMessageById,
  updateMessage,
  deleteMessage,
  getChildMessages,
} from "@features/messages/controller";
import {
  createThread,
  deleteThread,
  getThread,
  getThreads,
  updateThread,
  lockThread,
  unlockThread,
} from "@features/threads/controller";

const router = Router();

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /threads:
 *   get:
 *     tags: [Threads]
 *     summary: List threads
 *   post:
 *     tags: [Threads]
 *     summary: Create thread
 */
router.get("/", [paginationParser], asyncHandler(getThreads));
router.post("/", asyncHandler(createThread));
router
  .route("/:threadId")
  /**
   * @openapi
   * /threads/{threadId}:
   *   get:
   *     tags: [Threads]
   *     summary: Get thread
   *   put:
   *     tags: [Threads]
   *     summary: Update thread
   *   delete:
   *     tags: [Threads]
   *     summary: Delete thread
   */
  .get(asyncHandler(getThread))
  .put(asyncHandler(updateThread))
  .delete(asyncHandler(deleteThread));

/**
 * @openapi
 * /threads/{threadId}/lock:
 *   post:
 *     tags: [Threads]
 *     summary: Lock thread (author only)
 */
router.post("/:threadId/lock", asyncHandler(lockThread));

/**
 * @openapi
 * /threads/{threadId}/unlock:
 *   post:
 *     tags: [Threads]
 *     summary: Unlock thread (author only)
 */
router.post("/:threadId/unlock", asyncHandler(unlockThread));

router.get(
  "/:threadId/messages",
  [paginationParser],
  asyncHandler(getMessages)
);
/**
 * @openapi
 * /threads/{threadId}/messages:
 *   get:
 *     tags: [Threads]
 *     summary: List messages
 */
/**
 * @openapi
 * /threads/{threadId}/messages:
 *   post:
 *     tags: [Threads]
 *     summary: Create message
 */
router.post("/:threadId/messages", asyncHandler(createMessage));
router
  .route("/:threadId/messages/:messageId")
  /**
   * @openapi
   * /threads/{threadId}/messages/{messageId}:
   *   get:
   *     tags: [Threads]
   *     summary: Get message
   *   put:
   *     tags: [Threads]
   *     summary: Update message
   *   delete:
   *     tags: [Threads]
   *     summary: Delete message
   */
  .get(asyncHandler(getMessageById))
  .put(asyncHandler(updateMessage))
  .delete(asyncHandler(deleteMessage));

router.get(
  "/:threadId/child-messages/:parentId",
  [paginationParser],
  asyncHandler(getChildMessages)
);
/**
 * @openapi
 * /threads/{threadId}/child-messages/{parentId}:
 *   get:
 *     tags: [Threads]
 *     summary: Get child messages
 */

export default router;
