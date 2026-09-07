import { type IRequestContext, RequestContext, getAlphaNumericId, logger } from '@/common';
import { AsyncLocalStorage } from 'async_hooks';
import type { Request, Response, NextFunction } from 'express';

const asyncLocalStorage = new AsyncLocalStorage<IRequestContext>();

const requestContextMiddleware = async (req: Request, res: Response, next: NextFunction) => {
  // Generate a unique request ID or use one from headers if provided
  const requestId = (req.headers['x-request-id'] as string) || getAlphaNumericId();

  const startTime = Date.now();

  const context: IRequestContext = {
    requestId,
    timings: {
      start: startTime,
    },
  };

  try {
    RequestContext.run(context, () => {
      next();
    });
  } catch (error) {
    logger.error('In context error', error);
    next(error);
  }
};

export default requestContextMiddleware;
