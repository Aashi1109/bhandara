/**
 * @openapi
 * components:
 *   schemas:
 *     Event:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         description:
 *           type: string
 *         location:
 *           type: object
 *         status:
 *           type: string
 *         tags:
 *           type: array
 *           items:
 *             type: object
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
  sessionParser,
  userParser,
  validateParams,
  paginationParser,
} from "@/middlewares";

import {
  updateEvent,
  getEventById,
  createEvent,
  getEvents,
  deleteEventTag,
  eventJoinLeaveHandler,
  verifyEvent,
  deleteEventMedia,
  getEventThreads,
  deleteEvent,
  disassociateMediaFromEvent,
} from "@/features/events/controller";
import {
  createThread,
  deleteThread,
  getThread,
  updateThread,
  lockThread,
  unlockThread,
} from "@/features/threads/controller";
import {
  getMessages,
  createMessage,
  getMessageById,
  updateMessage,
  deleteMessage,
  getChildMessages,
} from "@/features/messages/controller";
import { BadRequestError } from "@/exceptions";
const router = Router();

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /events:
 *   get:
 *     tags: [Events]
 *     summary: List events
 *     responses:
 *       200:
 *         description: List of events
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Event'
 *   post:
 *     tags: [Events]
 *     summary: Create event
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Event'
 *     responses:
 *       201:
 *         description: Created event
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Event'
 */
router.route("/").get(asyncHandler(getEvents)).post(asyncHandler(createEvent));

router
  .route("/:eventId")
  /**
   * @openapi
   * /events/{eventId}:
   *   get:
   *     tags: [Events]
   *     summary: Get event by ID
   *     parameters:
   *       - in: path
   *         name: eventId
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Event data
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Event'
   *   put:
   *     tags: [Events]
   *     summary: Update event
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/Event'
   *     responses:
   *       200:
   *         description: Updated event
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Event'
   *   delete:
   *     tags: [Events]
   *     summary: Delete event
   *     responses:
   *       200:
   *         description: Deleted event
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Event'
   */
  .get([validateParams(["eventId"])], asyncHandler(getEventById))
  .put([validateParams(["eventId"])], asyncHandler(updateEvent))
  .delete([validateParams(["eventId"])], asyncHandler(deleteEvent));

/**
 * @openapi
 * /events/{eventId}/tags/{tagId}:
 *   delete:
 *     tags: [Events]
 *     summary: Remove tag from event
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: tagId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Tag removed
 */
router.delete(
  "/:eventId/tags/:tagId",
  [validateParams(["eventId", "tagId"])],
  asyncHandler(deleteEventTag)
);

/**
 * @openapi
 * /events/{eventId}/threads:
 *   get:
 *     tags: [Events]
 *     summary: Get threads for event
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of threads
 */
router.get(
  "/:eventId/threads",
  [validateParams(["eventId"])],
  asyncHandler(getEventThreads)
);

/**
 * @openapi
 * /events/{eventId}/threads:
 *   post:
 *     tags: [Events]
 *     summary: Create thread for event
 *     parameters:
 *       - in: path
 *         name: eventId
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
 *       201:
 *         description: Created thread
 */
router.post(
  "/:eventId/threads",
  [validateParams(["eventId"])],
  asyncHandler(createThread)
);

/**
 * @openapi
 * /events/{eventId}/threads/{threadId}:
 *   get:
 *     tags: [Events]
 *     summary: Get thread in event
 *   put:
 *     tags: [Events]
 *     summary: Update thread in event
 *   delete:
 *     tags: [Events]
 *     summary: Delete thread in event
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 */
router
  .route("/:eventId/threads/:threadId")
  .get([validateParams(["eventId", "threadId"])], asyncHandler(getThread))
  .put([validateParams(["eventId", "threadId"])], asyncHandler(updateThread))
  .delete(
    [validateParams(["eventId", "threadId"])],
    asyncHandler(deleteThread)
  );

/**
 * @openapi
 * /events/{eventId}/threads/{threadId}/{action}:
 *   post:
 *     tags: [Events]
 *     summary: Lock or unlock thread in event (author only)
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: threadId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: action
 *         required: true
 *         schema:
 *           type: string
 *           enum: [lock, unlock]
 *     responses:
 *       200:
 *         description: Thread lock/unlock result
 */
router.post(
  "/:eventId/threads/:threadId/:action",
  [validateParams(["eventId", "threadId", "action"])],
  asyncHandler((req: any, res: any) => {
    const { action } = req.params;
    if (action === "lock") return lockThread(req, res);
    else if (action === "unlock") return unlockThread(req, res);
    else throw new BadRequestError("Invalid action. Use 'lock' or 'unlock'");
  })
);

/**
 * @openapi
 * /events/{eventId}/threads/{threadId}/messages:
 *   get:
 *     tags: [Events]
 *     summary: List messages in thread
 *   post:
 *     tags: [Events]
 *     summary: Create message in thread
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
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
 */
router.get(
  "/:eventId/threads/:threadId/messages",
  [validateParams(["eventId", "threadId"]), paginationParser],
  asyncHandler(getMessages)
);
router.post(
  "/:eventId/threads/:threadId/messages",
  [validateParams(["eventId", "threadId"])],
  asyncHandler(createMessage)
);

/**
 * @openapi
 * /events/{eventId}/threads/{threadId}/messages/{messageId}:
 *   get:
 *     tags: [Events]
 *     summary: Get message in thread
 *   put:
 *     tags: [Events]
 *     summary: Update message in thread
 *   delete:
 *     tags: [Events]
 *     summary: Delete message in thread
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
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
 */
router
  .route("/:eventId/threads/:threadId/messages/:messageId")
  .get(
    [validateParams(["eventId", "threadId", "messageId"])],
    asyncHandler(getMessageById)
  )
  .put(
    [validateParams(["eventId", "threadId", "messageId"])],
    asyncHandler(updateMessage)
  )
  .delete(
    [validateParams(["eventId", "threadId", "messageId"])],
    asyncHandler(deleteMessage)
  );

/**
 * @openapi
 * /events/{eventId}/threads/{threadId}/child-messages/{parentId}:
 *   get:
 *     tags: [Events]
 *     summary: Get child messages in thread
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
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
 */
router.get(
  "/:eventId/threads/:threadId/child-messages/:parentId",
  [validateParams(["eventId", "threadId", "parentId"]), paginationParser],
  asyncHandler(getChildMessages)
);

/**
 * @openapi
 * /events/{eventId}/verify:
 *   post:
 *     tags: [Events]
 *     summary: Verify event attendance
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               currentCoordinates:
 *                 type: object
 *     responses:
 *       200:
 *         description: Verification result
 */
router.post("/:eventId/verify", asyncHandler(verifyEvent));

/**
 * @openapi
 * /events/{eventId}/{action}:
 *   get:
 *     tags: [Events]
 *     summary: Join or leave event
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: action
 *         required: true
 *         schema:
 *           type: string
 *           enum: [join, leave]
 *     responses:
 *       200:
 *         description: Join/leave status
 */
router.get(
  "/:eventId/:action",
  [validateParams(["eventId", "action"])],
  asyncHandler(eventJoinLeaveHandler)
);

/**
 * @openapi
 * /events/{eventId}/media/{mediaId}:
 *   delete:
 *     tags: [Events]
 *     summary: Delete event media
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: mediaId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Media deleted
 */
router.delete(
  "/:eventId/media/:mediaId",
  [validateParams(["eventId", "mediaId"])],
  asyncHandler(deleteEventMedia)
);

export default router;
