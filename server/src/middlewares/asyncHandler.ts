import type { NextFunction, Request, Response } from 'express';

/**
 * Async handler to wrap the API routes, allowing for async error handling.
 * @param fn Function to call for the API endpoint
 * @returns Promise with a catch statement
 */
const asyncHandler =
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (fn: (req: any, res: Response, next: NextFunction) => void) => (req: Request, res: Response, next: NextFunction) => {
    return Promise.resolve(fn(req, res, next)).catch(next);
  };

export default asyncHandler;
