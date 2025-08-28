import config from "@/config";
import { RequestContext } from "@/contexts";
import { ICustomRequest } from "@/definitions/types";
import { UnauthorizedError } from "@/exceptions";
import {
  AuthService,
  getUserSessionCache,
  updateUserSessionCache,
} from "@/features";
import { NextFunction, Request, Response } from "express";

const authService = new AuthService();

const sessionParser = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const jwtCookie = req.cookies?.[config.sessionCookie.keyName];

  if (!Boolean(jwtCookie))
    throw new UnauthorizedError(`Missing or invalid token`);

  const session = await getUserSessionCache(jwtCookie);

  if (!session)
    throw new UnauthorizedError(`Session not found, please login again`);

  // check if session is expired if expired then refresh the token
  if (new Date(session.expiresAt) < new Date()) {
    const newSession = await authService.refreshSession(session.refreshToken);
    session.accessToken = newSession.session.access_token;
    session.refreshToken = newSession.session.refresh_token;
    session.expiresAt = new Date(
      new Date(0).setUTCSeconds(newSession.session.expires_at)
    ).toISOString();
    session.expiresIn = newSession.session.expires_in;

    const res = await updateUserSessionCache(jwtCookie, session);
    if (res !== "OK")
      throw new UnauthorizedError(
        `Failed to refresh session, please login again`
      );
  }

  (req as ICustomRequest).session = session;
  RequestContext.setContextValue("session", {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
  });

  return next();
};

export default sessionParser;
