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
 */
import { Router } from "express";
import {
  asyncHandler,
  sessionParser,
  userParser,
  validateParams,
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
