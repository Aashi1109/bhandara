import { Router } from 'express';
import { asyncHandler, paginationParser, sessionParser, userParser } from '../middlewares';

import {
  getMessages,
  createMessage,
  getMessageById,
  updateMessage,
  deleteMessage,
  getChildMessages,
} from '@/features/messages/controller';
import {
  createThread,
  deleteThread,
  getThread,
  getThreads,
  updateThread,
  lockThread,
  unlockThread,
} from '@/features/threads/controller';

const router = Router();

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /threads:
 *   get:
 *     tags: [Threads]
 *     summary: List threads
 *     responses:
 *       200:
 *         description: Paginated threads
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedThreads'
 *                 error:
 *                   nullable: true
 *   post:
 *     tags: [Threads]
 *     summary: Create thread
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Thread'
 *     responses:
 *       201:
 *         description: Created thread
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Thread'
 *                 error:
 *                   nullable: true
 */
router.get('/', [paginationParser], asyncHandler(getThreads));
router.post('/', asyncHandler(createThread));
router
  .route('/:threadId')
  /**
   * @openapi
   * /threads/{threadId}:
   *   get:
   *     tags: [Threads]
   *     summary: Get thread
   *     parameters:
   *       - in: path
   *         name: threadId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Thread detail
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Thread'
   *                 error:
   *                   nullable: true
   *   put:
   *     tags: [Threads]
   *     summary: Update thread
   *     parameters:
   *       - in: path
   *         name: threadId
   *         required: true
   *         schema:
   *           type: string
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/Thread'
   *     responses:
   *       200:
   *         description: Updated thread
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Thread'
   *                 error:
   *                   nullable: true
   *   delete:
   *     tags: [Threads]
   *     summary: Delete thread
   *     parameters:
   *       - in: path
   *         name: threadId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Deleted thread
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Thread'
   *                 error:
   *                   nullable: true
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
 *     parameters:
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Locked thread
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Thread'
 *                 error:
 *                   nullable: true
 */
router.post('/:threadId/lock', asyncHandler(lockThread));

/**
 * @openapi
 * /threads/{threadId}/unlock:
 *   post:
 *     tags: [Threads]
 *     summary: Unlock thread (author only)
 *     parameters:
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Unlocked thread
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Thread'
 *                 error:
 *                   nullable: true
 */
router.post('/:threadId/unlock', asyncHandler(unlockThread));

router.get('/:threadId/messages', [paginationParser], asyncHandler(getMessages));
/**
 * @openapi
 * /threads/{threadId}/messages:
 *   get:
 *     tags: [Threads]
 *     summary: List messages
 *     parameters:
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Paginated messages
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedMessages'
 *                 error:
 *                   nullable: true
 */
/**
 * @openapi
 * /threads/{threadId}/messages:
 *   post:
 *     tags: [Threads]
 *     summary: Create message
 *     parameters:
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Message'
 *     responses:
 *       201:
 *         description: Created message
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/Message'
 *                 error:
 *                   nullable: true
 */
router.post('/:threadId/messages', asyncHandler(createMessage));
router
  .route('/:threadId/messages/:messageId')
  /**
   * @openapi
   * /threads/{threadId}/messages/{messageId}:
   *   get:
   *     tags: [Threads]
   *     summary: Get message
   *     parameters:
   *       - in: path
   *         name: threadId
   *         required: true
   *         schema:
   *           type: string
   *       - in: path
   *         name: messageId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Message detail
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Message'
   *                 error:
   *                   nullable: true
   *   put:
   *     tags: [Threads]
   *     summary: Update message
   *     parameters:
   *       - in: path
   *         name: threadId
   *         required: true
   *         schema:
   *           type: string
   *       - in: path
   *         name: messageId
   *         required: true
   *         schema:
   *           type: string
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/Message'
   *     responses:
   *       200:
   *         description: Updated message
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Message'
   *                 error:
   *                   nullable: true
   *   delete:
   *     tags: [Threads]
   *     summary: Delete message
   *     parameters:
   *       - in: path
   *         name: threadId
   *         required: true
   *         schema:
   *           type: string
   *       - in: path
   *         name: messageId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Deleted message
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 data:
   *                   $ref: '#/components/schemas/Message'
   *                 error:
   *                   nullable: true
   */
  .get(asyncHandler(getMessageById))
  .put(asyncHandler(updateMessage))
  .delete(asyncHandler(deleteMessage));

router.get('/:threadId/child-messages/:parentId', [paginationParser], asyncHandler(getChildMessages));
/**
 * @openapi
 * /threads/{threadId}/child-messages/{parentId}:
 *   get:
 *     tags: [Threads]
 *     summary: Get child messages
 *     parameters:
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: parentId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Paginated child messages
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedMessages'
 *                 error:
 *                   nullable: true
 */

export default router;
