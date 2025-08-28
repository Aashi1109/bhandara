import config from "@/config";
import { BadRequestError, UnauthorizedError } from "@/exceptions";
import sessionParser from "./sessionParser";
import userParser from "./userParser";

const socketUserParser = async (socket, next) => {
  try {
    const cookies = socket.request.headers?.cookie;
    const jwtCookie = cookies
      ?.split(";")
      .find((c: string) =>
        c.trim().startsWith(`${config.sessionCookie.keyName}`)
      );

    if (!jwtCookie) throw new BadRequestError(`Missing token`);
    const customReq: Record<string, any> = {
      cookies: {
        [config.sessionCookie.keyName]: jwtCookie.split("=")[1],
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
  } catch (error) {
    next(
      error?.message ||
        new UnauthorizedError(`Forbidden: Insufficient permissions`)
    );
  }
};

export default socketUserParser;
