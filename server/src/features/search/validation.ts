import Joi from 'joi';
import type { NextFunction, Request, Response } from 'express';
import { BadRequestError } from '@/common/exceptions';

export const searchQuerySchema = Joi.object({
  query: Joi.string().min(2).max(100).required(),
  next: Joi.string().allow(null, '').optional(),
  limit: Joi.number().integer().min(1).max(100).default(20),
  status: Joi.string().optional(),
  type: Joi.string().optional(),
  datePreset: Joi.string().valid('anytime', 'today', 'this_week', 'this_month').optional(),
  latitude: Joi.number().min(-90).max(90).optional(),
  longitude: Joi.number().min(-180).max(180).optional(),
  radiusKm: Joi.number().positive().max(1000).optional(),
  tagIds: Joi.string().optional(),
});

export const suggestionsQuerySchema = Joi.object({
  query: Joi.string().min(1).max(50).required(),
  limit: Joi.number().integer().min(1).max(20).default(5),
});

export const validateSearchRequest = (data: any) => searchQuerySchema.validate(data, { abortEarly: false });

const validateQuery = (schema: Joi.ObjectSchema) => {
  return (req: Request, _res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req.query, { abortEarly: false });

    if (error) {
      const errorMessage = error.details.map((detail) => detail.message).join(', ');
      throw new BadRequestError(`Validation error: ${errorMessage}`);
    }

    req.query = value as Request['query'];
    next();
  };
};

export const validateSearchQuery = validateQuery(searchQuerySchema);
export const validateSuggestionsQuery = validateQuery(suggestionsQuerySchema);
