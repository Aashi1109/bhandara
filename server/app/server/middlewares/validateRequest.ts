import { type NextFunction, type Request, type Response } from 'express';
import { validateSchema } from '@/common';

/**
 * Middleware to validate request body against an AJV schema.
 * @param schemaName - Unique name for the schema.
 * @param schema - JSON schema object.
 */
export const validateRequest = (schemaName: string, schema: object) => {
  const validator = validateSchema(schemaName, schema);

  return (req: Request, res: Response, next: NextFunction) => {
    validator(req.body, (validData) => {
      req.body = validData;
      next();
    });
  };
};

export default validateRequest;
