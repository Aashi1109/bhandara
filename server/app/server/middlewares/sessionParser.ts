import { config, type ICustomRequest, logger, RequestContext, UnauthorizedError } from '@/src/common';
import { AuthService, getUserSessionCache, updateUserSessionCache } from '@/src/features';
import type { NextFunction, Request, Response } from 'express';

const authService = new AuthService();

const sessionParser = async (req: Request, res: Response, next: NextFunction) => {
  const jwtCookie = req.signedCookies?.[config.sessionCookie.keyName] ?? req.cookies?.[config.sessionCookie.keyName];

  if (!jwtCookie) throw new UnauthorizedError(`Missing or invalid token`);

  const session = await getUserSessionCache(jwtCookie);

  if (!session) throw new UnauthorizedError(`Session not found, please login again`);

  // check if session is expired if expired then refresh the token
  if (new Date(session.expiresAt) < new Date()) {
    try {
      const newSession = await authService.refreshSession(session.refreshToken);
      session.accessToken = newSession.session!.access_token;
      session.refreshToken = newSession.session!.refresh_token;
      session.expiresAt = new Date(new Date(0).setUTCSeconds(newSession.session!.expires_at ?? 0)).toISOString();
      session.expiresIn = newSession.session!.expires_in;
      const cacheUpdateResult = await updateUserSessionCache(jwtCookie, session);
      if (cacheUpdateResult !== 'OK') throw new Error(`Failed to update session`);
    } catch (error) {
      logger.error(error);
      throw new UnauthorizedError(`Failed to refresh session, please login again`, { cause: error });
    }
  }

  (req as ICustomRequest).session = session;
  RequestContext.setContextValue('session', {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
  });

  return next();
};

export default sessionParser;
