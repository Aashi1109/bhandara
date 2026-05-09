import { Router } from 'express';

import { asyncHandler, sessionParser, userParser } from '../middlewares';
import {
  deleteEntityRating,
  getEntityEngagement,
  getEntityRatings,
  rateEntity,
  trackEntityView,
} from '@/features/engagement/controller';

const router = Router();

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /engagement/{entityType}/{entityId}:
 *   get:
 *     tags: [Engagement]
 *     summary: Get engagement summary for an entity
 *     parameters:
 *       - $ref: '#/components/parameters/EntityTypeParam'
 *       - $ref: '#/components/parameters/EntityIdParam'
 *     responses:
 *       200:
 *         description: Engagement summary
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/EntityEngagement'
 *                 error:
 *                   nullable: true
 */
router.get('/:entityType/:entityId', asyncHandler(getEntityEngagement));
/**
 * @openapi
 * /engagement/{entityType}/{entityId}/ratings:
 *   get:
 *     tags: [Engagement]
 *     summary: List ratings for an entity
 *     parameters:
 *       - $ref: '#/components/parameters/EntityTypeParam'
 *       - $ref: '#/components/parameters/EntityIdParam'
 *     responses:
 *       200:
 *         description: Ratings for the entity
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/:entityType/:entityId/ratings', asyncHandler(getEntityRatings));

/**
 * @openapi
 * /engagement/{entityType}/{entityId}/view:
 *   post:
 *     tags: [Engagement]
 *     summary: Track a unique entity view
 *     parameters:
 *       - $ref: '#/components/parameters/EntityTypeParam'
 *       - $ref: '#/components/parameters/EntityIdParam'
 *     responses:
 *       200:
 *         description: Updated engagement summary after recording the view
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/EntityEngagement'
 *                 error:
 *                   nullable: true
 */
router.post('/:entityType/:entityId/view', asyncHandler(trackEntityView));

/**
 * @openapi
 * /engagement/{entityType}/{entityId}/rating:
 *   put:
 *     tags: [Engagement]
 *     summary: Create or update the current user's rating for an entity
 *     parameters:
 *       - $ref: '#/components/parameters/EntityTypeParam'
 *       - $ref: '#/components/parameters/EntityIdParam'
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/RateEntityRequest'
 *     responses:
 *       200:
 *         description: Updated engagement summary after rating
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/EntityEngagement'
 *                 error:
 *                   nullable: true
 *   delete:
 *     tags: [Engagement]
 *     summary: Remove the current user's rating for an entity
 *     parameters:
 *       - $ref: '#/components/parameters/EntityTypeParam'
 *       - $ref: '#/components/parameters/EntityIdParam'
 *     responses:
 *       200:
 *         description: Updated engagement summary after deleting the rating
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/EntityEngagement'
 *                 error:
 *                   nullable: true
 */
router.put('/:entityType/:entityId/rating', asyncHandler(rateEntity));
router.delete('/:entityType/:entityId/rating', asyncHandler(deleteEntityRating));

export default router;
