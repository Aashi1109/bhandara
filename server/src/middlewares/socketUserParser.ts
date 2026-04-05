import config from '@/config';
import { BadRequestError, UnauthorizedError } from '@/exceptions';
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
        token = jwtCookie.split('=')[1];
      }
    }

    if (!token) throw new BadRequestError(`Missing token`);
    const customReq: Record<string, any> = {
      cookies: {
        [config.sessionCookie.keyName]: token,
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
    next(
      error instanceof Error
        ? error
        : new UnauthorizedError(`Forbidden: Insufficient permissions`),
    );
  }
};

export default socketUserParser;
