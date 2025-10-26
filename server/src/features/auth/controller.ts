import config from "@/config";
import { supabase } from "@/connections";
import { EAuthProvider } from "@/definitions/enums";
import { ICustomRequest } from "@/definitions/types";
import { BadRequestError, NotFoundError } from "@/exceptions";
import { AuthService } from "@/features";
import {
  deleteUserSessionCache,
  getUserSessionCacheList,
} from "@/features/users/helpers";
import UserService from "@/features/users/service";
import { isEmpty, merge } from "@/utils";
import { Request, Response } from "express";

const authService = new AuthService();
const userService = new UserService();

/**
 * Logins the user by creating a new access token
 * @param req Request object containing the request
 * @param res Response object containing the response
 */
const login = async (req: Request, res: Response) => {
  const { email, password } = req.body || {};

  if (!(email && password)) {
    throw new BadRequestError("Username and password are required");
  }

  const existingUser = await userService.getUserByEmail(email);

  if (!existingUser)
    throw new NotFoundError(`User not found with email: ${email}`);

  const loginProvider = existingUser.meta?.auth?.authProvider;
  if (!loginProvider) {
    existingUser.meta = merge(existingUser.meta, {
      auth: {
        authProvider: EAuthProvider.Email,
      },
    });
  }

  const isSocialLoggedInUser = [EAuthProvider.Google].includes(loginProvider);

  if (isSocialLoggedInUser) {
    throw new BadRequestError(
      `User signed in with ${loginProvider}, please login with the same ${loginProvider}`
    );
  }

  // TODO: Add if required
  // const token = await signJWTPayload(existingUser);

  const sessionData = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: sessionData,
    existingUser,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, {
    maxAge: config.sessionCookie.maxAge,
  });

  return res.status(200).json({
    data: { session: { id: sessionId }, user },
    success: true,
  });
};

const logOut = async (req: ICustomRequest, res: Response) => {
  await deleteUserSessionCache(
    req.user.id,
    req.cookies[config.sessionCookie.keyName]
  );
  res.clearCookie(config.sessionCookie.keyName);
  return res.status(200).json({ data: "Logout successful", success: true });
};

const session = (req: ICustomRequest, res: Response) => {
  const { user } = req;

  return res.status(200).json({
    data: { user, session: { id: req.cookies[config.sessionCookie.keyName] } },
  });
};

const googleAuth = async (req: Request, res: Response) => {
  const origin = config.baseUrl;
  const redirectUrl = `${origin}/api/auth/google/callback`;

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: redirectUrl },
  });

  if (error) throw new Error(error.message);

  return res.redirect(data.url);
};

const googleCallback = async (req: Request, res: Response) => {
  const exchangeCodeResponse = await supabase.auth.exchangeCodeForSession(
    req.query.code as string
  );

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: exchangeCodeResponse,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, {
    maxAge: config.sessionCookie.maxAge,
  });

  return res.json({
    data: {
      session: { id: sessionId },
      user,
    },
    success: true,
  });
};

export const signInWithIdToken = async (req: Request, res: Response) => {
  const clientIds = {
    android: config.google.androidClientId,
    ios: config.google.iosClientId,
    web: config.google.webClientId,
  };

  const clientPlatform = req.headers[
    "x-client-platform"
  ] as keyof typeof clientIds;

  const clientId =
    clientIds[req.headers["x-client-platform"] as keyof typeof clientIds] ||
    config.google.webClientId;

  const queryParams = new URLSearchParams();
  queryParams.set("client_id", clientId);
  if (clientPlatform === "web")
    queryParams.set("client_secret", config.google.clientSecret);

  queryParams.set("code", req.body.code);
  queryParams.set("grant_type", "authorization_code");
  queryParams.set("code_verifier", req.body.codeVerifier);
  queryParams.set("redirect_uri", req.body.redirectUri);

  const tokenRequest = await fetch("https://www.googleapis.com/oaut@/token", {
    method: "POST",
    body: queryParams,
  });

  const tokenResponse = await tokenRequest.json();

  const { access_token, id_token } = tokenResponse;

  if (!access_token) {
    throw new BadRequestError("Invalid access token");
  }

  const signInResponse = await supabase.auth.signInWithIdToken({
    provider: "google",
    token: id_token,
  });

  if (signInResponse.error) throw new Error(signInResponse.error.message);

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: signInResponse,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, {
    maxAge: config.sessionCookie.maxAge,
  });

  return res
    .status(200)
    .json({ data: { session: { id: sessionId }, user }, success: true });
};

export const sessionsList = async (req: ICustomRequest, res: Response) => {
  const sessions = await getUserSessionCacheList(req.user.id);
  return res.status(200).json({ data: sessions });
};

export const deleteSession = async (req: ICustomRequest, res: Response) => {
  const { sessionId } = req.params;
  await deleteUserSessionCache(req.user.id, sessionId);
  return res.status(200).json({ data: "Session deleted", success: true });
};

export const signUp = async (req: Request, res: Response) => {
  const { email, password, location, name } = req.body;
  const existingUser = await userService.getUserByEmail(email);

  if (!isEmpty(existingUser))
    throw new BadRequestError(`User already exists with email: ${email}`);

  const signUpData = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { location, name, full_name: name },
    },
  });

  const { sessionId, user } = await authService.createPlatformUser({
    req,
    sessionData: signUpData,
  });

  res.cookie(config.sessionCookie.keyName, sessionId, {
    maxAge: config.sessionCookie.maxAge,
  });

  return res.status(200).json({
    data: { session: { id: sessionId }, user },
    success: true,
  });
};

export const signInWithGoogleIdToken = async (req: Request, res: Response) => {
  const { token, clientType } = req.body;
  const { data, error } = await supabase.auth.signInWithIdToken({
    provider: "google",
    token,
  });

  if (error) throw new Error(error.message);

  return res.status(200).json({ data: null, success: true });
};

export { login, logOut, session, googleAuth, googleCallback };
