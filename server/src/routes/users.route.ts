/**
 * @openapi
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         email:
 *           type: string
 *         username:
 *           type: string
 *         profilePic:
 *           type: object
 *           nullable: true
 */
import { asyncHandler, paginationParser, sessionParser, userParser, validateRequest } from '@/middlewares';
import { Router } from 'express';
import {
  getAllUser,
  getUserById,
  deleteUser,
  updateUser,
  getUserByQuery,
  getUserInterests,
} from '@/features/users/controller';
import { updateSchema } from '@/features/users/validation';
import {
  getMyUpdates,
  getUserActivity,
  markAllUpdatesAsRead,
  markUpdateAsRead,
} from '@/features/activity/controller';
import {
  getUserAchievementProgress,
  getUserAchievements,
} from '@/features/achievements/controller';

const router = Router();

/**
 * @openapi
 * /users/query:
 *   get:
 *     tags: [Users]
 *     summary: Find user by email or username
 *     parameters:
 *       - in: query
 *         name: email
 *         schema:
 *           type: string
 *       - in: query
 *         name: username
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/User'
 *                 error:
 *                   nullable: true
 */
router.get('/query', asyncHandler(getUserByQuery));

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /users:
 *   get:
 *     tags: [Users]
 *     summary: List users
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Paginated users
 */
router.get('/', paginationParser, asyncHandler(getAllUser));

router.get('/me/updates', paginationParser, asyncHandler(getMyUpdates));
router.patch('/me/updates/read-all', asyncHandler(markAllUpdatesAsRead));
router.patch('/me/updates/:activityId/read', asyncHandler(markUpdateAsRead));

router.get('/:id/activity', paginationParser, asyncHandler(getUserActivity));
router.get('/:id/achievements', asyncHandler(getUserAchievements));
router.get('/:id/achievements/progress', asyncHandler(getUserAchievementProgress));

router
  .route('/:id')
  /**
   * @openapi
   * /users/{id}:
   *   get:
   *     tags: [Users]
   *     summary: Get user by ID
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Success
   */
  .get(asyncHandler(getUserById))
  /**
   * @openapi
   * /users/{id}:
   *   delete:
   *     tags: [Users]
   *     summary: Delete user
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: string
   *     responses:
   *       200:
   *         description: Deleted
   */
  .delete(asyncHandler(deleteUser))
  /**
   * @openapi
   * /users/{id}:
   *   patch:
   *     tags: [Users]
   *     summary: Update user
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: string
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             type: object
   *     responses:
   *       200:
   *         description: Updated
   */
  .patch(validateRequest('USER_UPDATE', updateSchema), asyncHandler(updateUser));

/**
 * @openapi
 * /users/{id}/interests:
 *   get:
 *     tags: [Users]
 *     summary: Get user interests
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of interests
 */
router.get('/:id/interests', asyncHandler(getUserInterests));

export default router;
