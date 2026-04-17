import { asyncHandler, paginationParser, rateLimit, sessionParser, userParser } from '@/middlewares';
import { Router } from 'express';
import {
  getAllUser,
  getUserById,
  deleteUser,
  updateUser,
  getUserByQuery,
  getUserInterests,
  getUserSettings,
  updateUserSettings,
  getUserImpact,
} from '@/features/users/controller';
import { validateUserUpdate, validateUserSettings } from '@/features/users/validation';
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

/**
 * @openapi
 * /users/me/updates:
 *   get:
 *     tags: [Users]
 *     summary: List the authenticated user's activity updates
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
 *       - in: query
 *         name: unreadOnly
 *         schema:
 *           type: boolean
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *         description: Comma-separated activity types.
 *     responses:
 *       200:
 *         description: Paginated activity updates
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedActivities'
 *                 error:
 *                   nullable: true
 */
router.get('/me/updates', paginationParser, asyncHandler(getMyUpdates));

/**
 * @openapi
 * /users/me/updates/read-all:
 *   patch:
 *     tags: [Users]
 *     summary: Mark every unread update as read for the authenticated user
 *     responses:
 *       200:
 *         description: Read status updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: boolean
 *                 error:
 *                   nullable: true
 */
router.patch('/me/updates/read-all', asyncHandler(markAllUpdatesAsRead));

/**
 * @openapi
 * /users/me/updates/{activityId}/read:
 *   patch:
 *     tags: [Users]
 *     summary: Mark a single activity update as read
 *     parameters:
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Updated activity item
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/ActivityItem'
 *                 error:
 *                   nullable: true
 *       404:
 *         description: Activity not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.patch('/me/updates/:activityId/read', asyncHandler(markUpdateAsRead));

/**
 * @openapi
 * /users/{id}/activity:
 *   get:
 *     tags: [Users]
 *     summary: Get a user's activity feed
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *       - in: query
 *         name: next
 *         schema:
 *           type: string
 *           nullable: true
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *         description: Comma-separated activity types.
 *       - in: query
 *         name: includePrivate
 *         schema:
 *           type: boolean
 *         description: Only applies when the authenticated user is requesting their own feed.
 *     responses:
 *       200:
 *         description: Paginated public activity feed
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/PaginatedActivities'
 *                 error:
 *                   nullable: true
 */
router.get('/:id/activity', paginationParser, asyncHandler(getUserActivity));

/**
 * @openapi
 * /users/{id}/achievements:
 *   get:
 *     tags: [Users]
 *     summary: Get a user's unlocked achievements and definitions
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *     responses:
 *       200:
 *         description: Achievement state for the user
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/UserAchievementsPayload'
 *                 error:
 *                   nullable: true
 */
router.get('/:id/achievements', asyncHandler(getUserAchievements));

/**
 * @openapi
 * /users/{id}/achievements/progress:
 *   get:
 *     tags: [Users]
 *     summary: Get a user's achievement progress metrics
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *     responses:
 *       200:
 *         description: Achievement progress for the user
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/AchievementProgress'
 *                 error:
 *                   nullable: true
 */
router.get('/:id/achievements/progress', asyncHandler(getUserAchievementProgress));

/**
 * @openapi
 * /users/{id}/impact:
 *   get:
 *     tags: [Users]
 *     summary: Get engagement impact for a user's created events
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *     responses:
 *       200:
 *         description: Aggregate impact metrics
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/UserImpactSummary'
 *                 error:
 *                   nullable: true
 */
router.get('/:id/impact', asyncHandler(getUserImpact));

/**
 * @openapi
 * /users/{id}/settings:
 *   get:
 *     tags: [Users]
 *     summary: Get persisted settings for a user
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *     responses:
 *       200:
 *         description: User settings
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/UserSettings'
 *                 error:
 *                   nullable: true
 *   patch:
 *     tags: [Users]
 *     summary: Update persisted settings for a user
 *     parameters:
 *       - $ref: '#/components/parameters/UserIdParam'
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UserSettingsUpdateRequest'
 *     responses:
 *       200:
 *         description: Updated user settings
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   $ref: '#/components/schemas/UserSettings'
 *                 error:
 *                   nullable: true
 *       400:
 *         description: Invalid settings payload
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/:id/settings', asyncHandler(getUserSettings));
router.patch('/:id/settings', validateUserSettings, asyncHandler(updateUserSettings));

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
  .patch(validateUserUpdate, asyncHandler(updateUser));

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
