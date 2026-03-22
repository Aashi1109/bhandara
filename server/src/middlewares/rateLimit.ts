import type { Request, Response, NextFunction } from "express";

import { getRedisConnection } from "@/connections/redis";
import { REDIS_CONNECTION_NAMES } from "@/constants";

type RateLimitOptions = {
  keyPrefix: string;
  limit: number;
  windowSeconds: number;
};

const getClientIp = (req: Request) => {
  const forwardedFor = req.headers["x-forwarded-for"];
  if (typeof forwardedFor === "string" && forwardedFor.length > 0) {
    return forwardedFor.split(",")[0].trim();
  }

  return req.socket.remoteAddress || "unknown";
};

export default function rateLimit(options: RateLimitOptions) {
  const redis = getRedisConnection(REDIS_CONNECTION_NAMES.RateLimit);

  return async function rateLimitMiddleware(
    req: Request,
    res: Response,
    next: NextFunction,
  ) {
    try {
      const currentWindow = Math.floor(Date.now() / 1000 / options.windowSeconds);
      const ip = getClientIp(req);
      const key = `${options.keyPrefix}:${ip}:${currentWindow}`;

      const currentCount = await redis.incr(key);
      if (currentCount === 1) {
        await redis.expire(key, options.windowSeconds);
      }

      res.setHeader("X-RateLimit-Limit", options.limit.toString());
      res.setHeader("X-RateLimit-Remaining", Math.max(0, options.limit - currentCount).toString());
      res.setHeader("X-RateLimit-Window", options.windowSeconds.toString());

      if (currentCount > options.limit) {
        return res.status(429).json({
          data: null,
          error: "Too many requests. Please try again later.",
        });
      }

      return next();
    } catch (error) {
      return next(error);
    }
  };
}
