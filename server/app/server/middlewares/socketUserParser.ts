import { BadRequestError, config, UnauthorizedError } from '@/common';
import sessionParser from './sessionParser';
import userParser from './userParser';

const socketUserParser = async (socket: any, next: any) => {
  try {
    // Token can arrive as a query parameter (mobile/native WebSocket clients)
    // or as a cookie header (browser clients).
    const queryToken = socket.handshake?.query?.token as string | undefined;
    let token: string | undefined;

    if (queryToken) {
      token = queryToken;
    } else {
      const cookies = socket.request.headers?.cookie;
      const jwtCookie = cookies?.split(';').find((c: string) => c.trim().startsWith(`${config.sessionCookie.keyName}`));
      if (jwtCookie) {
        // Use slice(1).join('=') to correctly handle cookie values containing '=' (e.g. base64)
        token = jwtCookie.split('=').slice(1).join('=').trim();
      }
    }

    if (!token) throw new BadRequestError(`Missing token`);

    // Signed cookies from cookie-parser have the format "s:<value>.<signature>".
    // Strip the prefix so the bare session ID is placed in signedCookies, matching
    // what sessionParser now reads. Redis validates the ID, so signature re-check
    // is not needed on this already-authenticated socket upgrade path.
    const bareToken = token.startsWith('s:') ? token.slice(2).split('.')[0] : token;

    const customReq: Record<string, any> = {
      cookies: {},
      signedCookies: {
        [config.sessionCookie.keyName]: bareToken,
      },
    };
    let error;
    await sessionParser(customReq as any, socket.request.res, async () => {
      await userParser(customReq as any, socket.request.res, async (err) => {
        error = err;
      });
    });
    socket.request.user = customReq?.user;
    socket.request.session = customReq?.session;

    next(error);
  } catch (error: unknown) {
    next(error instanceof Error ? error : new UnauthorizedError(`Forbidden: Insufficient permissions`));
  }
};

export default socketUserParser;
