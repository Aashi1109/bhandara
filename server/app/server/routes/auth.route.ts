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
  forgotPassword,
  verifyForgotPasswordOTP,
  resetPassword,
} from '@/features/auth/controller';
import { sessionParser, userParser, asyncHandler, rateLimit } from '../middlewares';

import {
  validateLogin,
  validateSignup,
  validateSignInWithIdToken,
  validateForgotPassword,
  validateVerifyOTP,
  validateResetPassword,
} from '@/features/auth/validation';

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
router.post(
  '/login',
  rateLimit({ keyPrefix: 'auth_login', limit: 10, windowSeconds: 60 }),
  validateLogin,
  asyncHandler(login),
);
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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 */
router.post(
  '/signup',
  rateLimit({ keyPrefix: 'auth_signup', limit: 5, windowSeconds: 60 }),
  validateSignup,
  asyncHandler(signUp),
);
/**
 * @openapi
 * /auth/oauth/signin-with-id-token:
 *   post:
 *     tags: [Auth]
 *     summary: Signin with OAuth id token
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               provider:
 *                 type: string
 *               idToken:
 *                 type: string
 *     security: []
 *     responses:
 *       200:
 *         description: Signin success
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AuthResponse'
 */
router.post(
  '/oauth/signin-with-id-token',
  rateLimit({ keyPrefix: 'auth_oauth', limit: 10, windowSeconds: 60 }),
  validateSignInWithIdToken,
  asyncHandler(signInWithIdToken),
);

/**
 * @openapi
 * /auth/forgot-password:
 *   post:
 *     tags: [Auth]
 *     summary: Request a password reset OTP
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
 *     responses:
 *       200:
 *         description: OTP sent (response is the same regardless of whether the email exists)
 */
router.post(
  '/forgot-password',
  rateLimit({ keyPrefix: 'auth_forgot', limit: 5, windowSeconds: 300 }),
  validateForgotPassword,
  asyncHandler(forgotPassword),
);

/**
 * @openapi
 * /auth/forgot-password/verify:
 *   post:
 *     tags: [Auth]
 *     summary: Verify the OTP and receive a short-lived reset token
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
 *               code:
 *                 type: string
 *     responses:
 *       200:
 *         description: Returns a one-time reset token
 */
router.post(
  '/forgot-password/verify',
  rateLimit({ keyPrefix: 'auth_otp_verify', limit: 5, windowSeconds: 300 }),
  validateVerifyOTP,
  asyncHandler(verifyForgotPasswordOTP),
);

/**
 * @openapi
 * /auth/reset-password:
 *   post:
 *     tags: [Auth]
 *     summary: Set a new password using the reset token
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Password updated successfully
 */
router.post(
  '/reset-password',
  rateLimit({ keyPrefix: 'auth_reset', limit: 5, windowSeconds: 300 }),
  validateResetPassword,
  asyncHandler(resetPassword),
);

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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/logout', asyncHandler(logOut));
/**
 * @openapi
 * /auth/session:
 *   get:
 *     tags: [Auth]
 *     summary: Get current session
 *     responses:
 *       200:
 *         description: Current session
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
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
 *     responses:
 *       200:
 *         description: Session deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.delete('/session/:sessionId', asyncHandler(deleteSession));
/**
 * @openapi
 * /auth/sessions:
 *   get:
 *     tags: [Auth]
 *     summary: List sessions
 *     responses:
 *       200:
 *         description: Active sessions
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiEnvelope'
 */
router.get('/sessions', asyncHandler(sessionsList));

export default router;
