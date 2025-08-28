import { IRequestContext, RequestContext } from "@/contexts";
import { getAlphaNumericId } from "@/helpers";
import logger from "@/logger";
import { AsyncLocalStorage } from "async_hooks";
import { Request, Response, NextFunction } from "express";

const asyncLocalStorage = new AsyncLocalStorage<IRequestContext>();

const requestContextMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Generate a unique request ID or use one from headers if provided
  const requestId =
    (req.headers["x-request-id"] as string) || getAlphaNumericId();

  const startTime = Date.now();

  const context: IRequestContext = {
    requestId,
    timings: {
      start: startTime,
    },
  };

  // res.on("finish", () => {
  //   const endTime = Date.now();
  //   const totalTime = endTime - startTime;
  //   context.timings = {
  //     ...context.timings,
  //     end: endTime,
  //     total: totalTime,
  //   };

  //   logger.info(
  //     `Request ID: [${requestId}] ${req.method} ${req.url} ${totalTime}ms ${res.statusCode}`
  //   );
  //   return next();
  // });

  // res.setHeader("X-Request-ID", requestId);
  // Store the original next function

  try {
    RequestContext.run(context, async () => {
      next();
    });
  } catch (error) {
    logger.error("In context error", error);
  }
};

export default requestContextMiddleware;
