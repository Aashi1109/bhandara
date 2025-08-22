import Joi from "joi";
import { EEventStatus, EEventType } from "@definitions/enums";

export const searchQuerySchema = Joi.object({
  query: Joi.string().min(2).max(100).required(),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  filters: Joi.object({
    types: Joi.array().items(
      Joi.string().valid('event', 'user', 'tag')
    ),
    eventStatus: Joi.array().items(
      Joi.string().valid(...Object.values(EEventStatus))
    ),
    eventType: Joi.array().items(
      Joi.string().valid(...Object.values(EEventType))
    ),
    dateRange: Joi.object({
      start: Joi.string().isoDate().required(),
      end: Joi.string().isoDate().required(),
    }),
    location: Joi.object({
      latitude: Joi.number().min(-90).max(90).required(),
      longitude: Joi.number().min(-180).max(180).required(),
      radius: Joi.number().positive().max(1000).required(), // max 1000km
    }),
    tags: Joi.array().items(Joi.string()),
  }),
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