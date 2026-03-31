import Joi from 'joi';

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

export const validateSearchRequest = (data: any) => {
  return searchQuerySchema.validate(data, { abortEarly: false });
};

export const validateSuggestionsRequest = (data: any) => {
  return suggestionsQuerySchema.validate(data, { abortEarly: false });
};
