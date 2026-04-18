import config from '@/src/common/config';
import { supabase } from '@/src/common/connections';
import supabaseAdmin from '@/src/common/connections/supabase/admin';
import { EAuthProvider } from '@/src/common/definitions/enums';
import type { ICustomRequest } from '@/src/common/definitions/types';
import { BadRequestError, NotFoundError, UnauthorizedError } from '@/src/common/exceptions';
import { isEmpty, merge } from '@/src/common/utils';
import { AuthService } from '@/src/features';
import { deleteUserSessionCache, getUserSessionCacheList } from '@/src/features/users/helpers';
import UserService from '@/src/features/users/service';
import type { Request, Response } from 'express';
import {
  generateOTP,
  generateResetToken,
  storeOTP,
  storeResetToken,
  verifyOTP,
  consumeResetToken,
} from './otp-helpers';
import { sendPasswordResetOTPEmail, sendPasswordResetSuccessEmail } from '@/src/features/email/service';

const authService = new AuthService();
const userService = new UserService();

const getSessionCookieOptions = (req: Request) => {
  const originHeader = req.headers?.origin;
  const hostHeader = req.headers?.host;
  const originHost = (() => {
    if (typeof originHeader !== 'string') return null;
    try {
      return new URL(originHeader).host.toLowerCase();
    } catch (_) {
      return null;
    }
  })();
  const requestHost = typeof hostHeader === 'string' ? hostHeader.toLowerCase() : null;
  const isCrossOrigin = originHost !== null && requestHost !== null && originHost !== requestHost;

  return {
    httpOnly: true,
    signed: true,
    maxAge: config.sessionCookie.maxAge,
    path: '/',
    sameSite: isCrossOrigin ? 'none' : 'lax',
    secure: isCrossOrigin,
  } as const;
};

/**
 * Logins the user by creating a new access token
 * @param req Request object containing the request
 * @param res Response object containing the response
 */
const login = async (req: Request, res: Response) => {
  const { email, password } = req.body || {};

  if (!(email && password)) {
    throw new BadRequestError('Username and password are required');
  }

  const existingUser = await userService.getUserByEmail(email);

  if (!existingUser) throw new UnauthorizedError('Invalid email or password');

  const provider = existingUser.meta?.auth?.provider || existingUser.meta?.provider;
  if (!provider) {
    existingUser.meta = merge(existingUser.meta, {
      auth: {
        provider: EAuthProvider.Email,
      },
      provider: EAuthProvider.Email,
    });
  }

  const isSocialLoggedInUser = [EAuthProvider.Google].includes(provider);

  if (isSocialLoggedInUser) {
    throw new BadRequestError(`User signed in with ${provider}, please login with the same ${provider}`);
  }

  // TODO: Add if required
  // const token = await signJWTPayload(existingUser);

  const sessionData = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData,
    existingUser,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, getSessionCookieOptions(req));

  return res.status(200).json({
    data: { session: { id: sessionId }, user },
  });
};

const logOut = async (req: ICustomRequest, res: Response) => {
  await deleteUserSessionCache(req.user.id, req.signedCookies[config.sessionCookie.keyName]);
  res.clearCookie(config.sessionCookie.keyName, getSessionCookieOptions(req));
  return res.status(200).json({ data: 'Logout successful' });
};

const session = (req: ICustomRequest, res: Response) => {
  const { user } = req;

  return res.status(200).json({
    data: { user, session: { id: req.signedCookies[config.sessionCookie.keyName] } },
  });
};

const googleAuth = async (req: Request, res: Response) => {
  const redirectUrl = `${config.baseUrl}/api/auth/google/callback`;

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: redirectUrl },
  });

  if (error) throw new Error(error.message);

  return res.status(200).json({
    data: {
      url: data.url,
    },
  });
};

const googleCallback = async (req: Request, res: Response) => {
  const exchangeCodeResponse = await supabase.auth.exchangeCodeForSession(req.query.code as string);

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: exchangeCodeResponse,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, getSessionCookieOptions(req));

  return res.json({
    data: {
      session: { id: sessionId },
      user,
    },
  });
};

export const signInWithIdToken = async (req: Request, res: Response) => {
  const { token, code, codeVerifier, redirectUri } = req.body;

  let signInResponse;

  if (token) {
    // Mobile ID token flow: validate the Google ID token directly via Supabase
    signInResponse = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token,
    });
  } else if (code) {
    // Authorization code exchange flow (web/PKCE)
    const clientIds = {
      android: config.google.androidClientId,
      ios: config.google.iosClientId,
      web: config.google.webClientId,
    };

    const clientPlatform = req.headers['x-client-platform'] as keyof typeof clientIds;
    const clientId = clientIds[clientPlatform] || config.google.webClientId;

    const queryParams = new URLSearchParams();
    queryParams.set('client_id', clientId);
    if (clientPlatform === 'web') queryParams.set('client_secret', config.google.clientSecret);
    queryParams.set('code', code);
    queryParams.set('grant_type', 'authorization_code');
    queryParams.set('code_verifier', codeVerifier);
    queryParams.set('redirect_uri', redirectUri);

    const tokenRequest = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      body: queryParams,
    });

    const tokenResponse = await tokenRequest.json();
    const { access_token, id_token } = tokenResponse;

    if (!access_token) {
      throw new BadRequestError('Invalid access token');
    }

    signInResponse = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: id_token,
    });
  } else {
    throw new BadRequestError('Either token or code is required');
  }

  if (signInResponse.error) throw new Error(signInResponse.error.message);

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: signInResponse,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, getSessionCookieOptions(req));

  return res.status(200).json({ data: { session: { id: sessionId }, user } });
};

export const sessionsList = async (req: ICustomRequest, res: Response) => {
  const sessions = await getUserSessionCacheList(req.user.id);
  return res.status(200).json({ data: sessions });
};

export const deleteSession = async (req: ICustomRequest, res: Response) => {
  const { sessionId } = req.params;
  await deleteUserSessionCache(req.user.id, sessionId as string);
  return res.status(200).json({ data: 'Session deleted' });
};

export const signUp = async (req: Request, res: Response) => {
  const { email, password, location, name, gender } = req.body;
  const existingUser = await userService.getUserByEmail(email);

  if (!isEmpty(existingUser)) throw new BadRequestError(`User already exists with email: ${email}`);

  const signUpData = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { location, name, full_name: name, gender },
    },
  });

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: signUpData,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, getSessionCookieOptions(req));

  return res.status(200).json({
    data: { session: { id: sessionId }, user },
  });
};

export const forgotPassword = async (req: Request, res: Response) => {
  const { email } = req.body;

  // Always return 200 to avoid user enumeration
  const user = await userService.getUserByEmail(email);
  if (!user) {
    return res.status(200).json({ data: 'If that email exists, a reset code has been sent.' });
  }

  const provider = user.meta?.auth?.provider || user.meta?.provider;
  if (provider && provider !== EAuthProvider.Email) {
    return res.status(200).json({ data: 'If that email exists, a reset code has been sent.' });
  }

  const otp = generateOTP();
  await storeOTP(email, otp);
  await sendPasswordResetOTPEmail(email, otp);

  return res.status(200).json({ data: 'If that email exists, a reset code has been sent.' });
};

export const verifyForgotPasswordOTP = async (req: Request, res: Response) => {
  const { email, code } = req.body;

  const result = await verifyOTP(email, code);
  if (!result.valid) {
    throw new BadRequestError(result.reason ?? 'Invalid code');
  }

  const token = generateResetToken();
  await storeResetToken(token, email);

  return res.status(200).json({ data: { token } });
};

export const resetPassword = async (req: Request, res: Response) => {
  const { token, email, password } = req.body;

  const storedEmail = await consumeResetToken(token);
  if (!storedEmail || storedEmail !== email) {
    throw new UnauthorizedError('Invalid or expired reset token');
  }
  const user = await userService.getUserByEmail(email);
  if (!user) throw new NotFoundError('User not found');
  const supabaseUserId = user.__sid;
  if (!supabaseUserId) {
    throw new NotFoundError('Auth account not found');
  }
  const { data: sbUserData, error: lookupError } = await supabaseAdmin.auth.admin.getUserById(supabaseUserId);
  const sbUser = sbUserData?.user;
  if (lookupError || !sbUser) throw new NotFoundError('Auth account not found');

  const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(sbUser.id, { password });
  if (updateError) throw new BadRequestError(updateError.message);

  await sendPasswordResetSuccessEmail(email);

  return res.status(200).json({ data: 'Password reset successfully' });
};

export { login, logOut, session, googleAuth, googleCallback };
