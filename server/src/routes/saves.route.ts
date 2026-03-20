import { Router } from 'express';

import {
  asyncHandler,
  paginationParser,
  sessionParser,
  userParser,
} from '@/middlewares';
import {
  getSavedEntityState,
  listSavedEntities,
  saveEntity,
  unsaveEntity,
} from '@/features/saves/controller';

const router = Router();

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /saves:
 *   get:
 *     tags: [Saves]
 *     summary: List the current user's saved entities
 *     parameters:
 *       - in: query
 *         name: entityType
 *         required: false
 *         schema:
 *           type: string
 *           enum: [event, thread, message]
 *     responses:
 *       200:
 *         description: Paginated saved entities
 */
router.get('/', [paginationParser], asyncHandler(listSavedEntities));

/**
 * @openapi
 * /saves/{entityType}/{entityId}:
 *   get:
 *     tags: [Saves]
 *     summary: Get the current user's save state for an entity
 *     parameters:
 *       - in: path
 *         name: entityType
 *         required: true
 *         schema:
 *           type: string
 *           enum: [event, thread, message]
 *       - in: path
 *         name: entityId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Save state for the entity
 *   put:
 *     tags: [Saves]
 *     summary: Save an entity for the current user
 *     parameters:
 *       - in: path
 *         name: entityType
 *         required: true
 *         schema:
 *           type: string
 *           enum: [event, thread, message]
 *       - in: path
 *         name: entityId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Saved entity state
 *   delete:
 *     tags: [Saves]
 *     summary: Remove an entity from the current user's saves
 *     parameters:
 *       - in: path
 *         name: entityType
 *         required: true
 *         schema:
 *           type: string
 *           enum: [event, thread, message]
 *       - in: path
 *         name: entityId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Unsaved entity state
 */
router
  .route('/:entityType/:entityId')
  .get(asyncHandler(getSavedEntityState))
  .put(asyncHandler(saveEntity))
  .delete(asyncHandler(unsaveEntity));

export default router;
