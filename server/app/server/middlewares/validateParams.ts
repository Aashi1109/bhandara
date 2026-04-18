import { BadRequestError } from '@/src/common';
import type { NextFunction, Request, Response } from 'express';

const validateParams = (paramNames: string[]) => {
  return (req: Request, _: Response, next: NextFunction) => {
    const missingParams = paramNames.filter((param) => !req.params[param]);

    if (missingParams.length > 0) {
      throw new BadRequestError(`Missing required parameters: ${missingParams.join(', ')}`);
    }

    next();
  };
};

export default validateParams;
