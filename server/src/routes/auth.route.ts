import { Router } from 'express';
import {
  logOut,
  session,
  login,
  googleAuth,
  googleCallback,
  sessionsList,
  deleteSession,
  signUp,
  signInWithIdToken,
} from '@/features/auth/controller';
import { sessionParser, userParser, asyncHandler, validateRequest } from '@/middlewares';

import { schemas } from '@/features/auth/validation';

const router = Router();

/**
 * @openapi
 * /auth/login:
 *   post:
 *     tags: [Auth]
 *     summary: User login
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login success
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 */
router.post('/login', validateRequest('AUTH_LOGIN', schemas.login), asyncHandler(login));
/**
 * @openapi
 * /auth/google/callback:
 *   get:
 *     tags: [Auth]
 *     summary: Google OAuth callback
 *     security: []
 *     responses:
 *       200:
 *         description: OAuth success
 */
router.get('/google/callback', asyncHandler(googleCallback));
/**
 * @openapi
 * /auth/google:
 *   get:
 *     tags: [Auth]
 *     summary: Get Google OAuth redirect URL
 *     security: []
 *     responses:
 *       200:
 *         description: OAuth URL
 */
router.get('/google', asyncHandler(googleAuth));
/**
 * @openapi
 * /auth/signup:
 *   post:
 *     tags: [Auth]
 *     summary: Sign up user
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Signup success
 */
router.post('/signup', validateRequest('AUTH_SIGNUP', schemas.signup), asyncHandler(signUp));
/**
 * @openapi
 * /auth/oauth/signin-with-id-token:
 *   post:
 *     tags: [Auth]
 *     summary: Signin with OAuth id token
 *     security: []
 *     responses:
 *       200:
 *         description: Signin success
 */
router.post('/oauth/signin-with-id-token', asyncHandler(signInWithIdToken));

router.use([sessionParser, userParser]);
/**
 * @openapi
 * /auth/logout:
 *   get:
 *     tags: [Auth]
 *     summary: Logout user
 *     responses:
 *       200:
 *         description: Logged out
 */
router.get('/logout', asyncHandler(logOut));
/**
 * @openapi
 * /auth/session:
 *   get:
 *     tags: [Auth]
 *     summary: Get current session
 */
router.get('/session', asyncHandler(session));
/**
 * @openapi
 * /auth/session/{sessionId}:
 *   delete:
 *     tags: [Auth]
 *     summary: Delete session
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 */
router.delete('/session/:sessionId', asyncHandler(deleteSession));
/**
 * @openapi
 * /auth/sessions:
 *   get:
 *     tags: [Auth]
 *     summary: List sessions
 */
router.get('/sessions', asyncHandler(sessionsList));

export default router;
