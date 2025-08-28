import { Router } from "express";
/**
 * @openapi
 * components:
 *   schemas:
 *     AuthResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *         data:
 *           type: object
 */
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
} from "@/features/auth/controller";
import { sessionParser, userParser, asyncHandler } from "@/middlewares";

const router = Router();

/**
 * @openapi
 * /auth/login:
 *   post:
 *     tags: [Auth]
 *     summary: User login
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
router.post("/login", asyncHandler(login));
/**
 * @openapi
 * /auth/google/callback:
 *   get:
 *     tags: [Auth]
 *     summary: Google OAuth callback
 *     responses:
 *       200:
 *         description: OAuth success
 */
router.get("/google/callback", asyncHandler(googleCallback));
/**
 * @openapi
 * /auth/google:
 *   get:
 *     tags: [Auth]
 *     summary: Redirect to Google OAuth
 *     responses:
 *       302:
 *         description: Redirect
 */
router.get("/google", asyncHandler(googleAuth));
/**
 * @openapi
 * /auth/signup:
 *   post:
 *     tags: [Auth]
 *     summary: Sign up user
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
router.post("/signup", asyncHandler(signUp));
/**
 * @openapi
 * /auth/oauth/signin-with-id-token:
 *   post:
 *     tags: [Auth]
 *     summary: Signin with OAuth id token
 *     responses:
 *       200:
 *         description: Signin success
 */
router.post("/oauth/signin-with-id-token", asyncHandler(signInWithIdToken));

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
router.get("/logout", asyncHandler(logOut));
/**
 * @openapi
 * /auth/session:
 *   get:
 *     tags: [Auth]
 *     summary: Get current session
 */
router.get("/session", asyncHandler(session));
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
router.delete("/session/:sessionId", asyncHandler(deleteSession));
/**
 * @openapi
 * /auth/sessions:
 *   get:
 *     tags: [Auth]
 *     summary: List sessions
 */
router.get("/sessions", asyncHandler(sessionsList));

export default router;
