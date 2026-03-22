import { asyncHandler, paginationParser, rateLimit, sessionParser, userParser, validateRequest } from '@/middlewares';
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
import { getMyUpdates, getUserActivity, markAllUpdatesAsRead, markUpdateAsRead } from '@/features/activity/controller';
import { getUserAchievementProgress, getUserAchievements } from '@/features/achievements/controller';

const router = Router();

/**
 * @openapi
 * /users/query:
 *   get:
 *     tags: [Users]
 *     summary: Find user by email or username
 *     description: Public lookup endpoint with IP-based rate limiting. Returns a public-safe user shape without email.
 *     security: []
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
 *                   $ref: '#/components/schemas/PublicUser'
 *                 error:
 *                   nullable: true
 *       429:
 *         $ref: '#/components/responses/RateLimited'
 */
router.get(
  '/query',
  rateLimit({
    keyPrefix: 'public-user-query',
    limit: 10,
    windowSeconds: 60,
  }),
  asyncHandler(getUserByQuery),
);

router.use([sessionParser, userParser]);

/**
 * @openapi
 * /users:
 *   get:
 *     tags: [Users]
 *     summary: List users
 *     parameters:
 *       - in: query
 *         name: next
 *         schema:
 *           type: string
 *           nullable: true
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Paginated users
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedUsers'
 *                 error:
 *                   nullable: true
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
   *       - $ref: '#/components/parameters/UserIdParam'
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
  .get(asyncHandler(getUserById))
  /**
   * @openapi
   * /users/{id}:
   *   delete:
   *     tags: [Users]
   *     summary: Delete user
   *     parameters:
   *       - $ref: '#/components/parameters/UserIdParam'
   *     responses:
   *       200:
   *         description: Deleted
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
  .delete(asyncHandler(deleteUser))
  /**
   * @openapi
   * /users/{id}:
   *   patch:
   *     tags: [Users]
   *     summary: Update user
   *     parameters:
   *       - $ref: '#/components/parameters/UserIdParam'
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             type: object
   *     responses:
   *       200:
   *         description: Updated
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
  .patch(validateRequest('USER_UPDATE', updateSchema), asyncHandler(updateUser));

/**
 * @openapi
 * /users/{id}/interests:
 *   get:
 *     tags: [Users]
 *     summary: Get user interests
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *     responses:
 *       200:
 *         description: List of interests
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Tag'
 *                 error:
 *                   nullable: true
 */
router.get('/:id/interests', asyncHandler(getUserInterests));

export default router;
