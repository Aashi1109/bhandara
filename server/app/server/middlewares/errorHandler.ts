import { logger, CustomError } from '@/common';
import type { NextFunction, Request, Response } from 'express';

/**
 * Handles errors and sends appropriate HTTP responses.
 * @function errorHandler
 * @param {unknown} err - The error object.
 * @param {Request} req - The Express request object.
 * @param {Response} res - The Express response object.
 * @param {NextFunction} next - The Express next function.
 */
const errorHandler = (err: unknown, req: Request, res: Response, next: NextFunction) => {
  logger.error(err);

  if (!(err instanceof CustomError)) {
    const error = err instanceof Error ? err : new Error('Unknown error');
    return res.status((err as any)?.status || 500).json({
      data: null,
      error: {
        message: error.message || 'Internal server error. Try again later',
        type: error.name || 'InternalServerError',
        status: (err as any)?.status || 500,
      },
    });
  }

  const response: {
    message: string;
    additionalInfo?: unknown;
    type?: string;
    status?: number;
  } = { message: err.message };

  if (err.additionalInfo) {
    response.additionalInfo = err.additionalInfo;
  }

  if (err.name) response.type = err.name;
  if (err.status) response.status = err.status;

  return res.status(err.status).json({ data: null, error: response });
};

export default errorHandler;
