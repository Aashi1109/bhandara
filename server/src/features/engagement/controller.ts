import type { ICustomRequest } from "@/definitions/types";
import { BadRequestError, NotFoundError } from "@/exceptions";
import type { Response } from "express";

import EntityEngagementService from "./service";

const entityEngagementService = new EntityEngagementService();
const asString = (value: string | string[] | undefined) =>
  Array.isArray(value) ? value[0] : value;

const getViewerIp = (req: ICustomRequest) => {
  const forwardedFor = req.headers["x-forwarded-for"];
  if (typeof forwardedFor === "string" && forwardedFor.length > 0) {
    return forwardedFor.split(",")[0].trim();
  }

  return req.socket.remoteAddress || null;
};

export const getEntityEngagement = async (
  req: ICustomRequest,
  res: Response,
) => {
  const entityType = asString(req.params.entityType);
  const entityId = asString(req.params.entityId);

  if (!entityType || !entityId) {
    throw new BadRequestError("Missing entity params");
  }

  if (!entityEngagementService.isSupportedEntityType(entityType)) {
    throw new BadRequestError("Unsupported entity type");
  }

  const data = await entityEngagementService.getStats(
    entityType,
    entityId,
    req.user?.id,
  );
  return res.status(200).json({ data });
};

export const getEntityRatings = async (
  req: ICustomRequest,
  res: Response,
) => {
  const entityType = asString(req.params.entityType);
  const entityId = asString(req.params.entityId);

  if (!entityType || !entityId) {
    throw new BadRequestError("Missing entity params");
  }

  if (!entityEngagementService.isSupportedEntityType(entityType)) {
    throw new BadRequestError("Unsupported entity type");
  }

  const data = await entityEngagementService.getRatings(entityType, entityId);
  return res.status(200).json({ data });
};

export const rateEntity = async (req: ICustomRequest, res: Response) => {
  const entityType = asString(req.params.entityType);
  const entityId = asString(req.params.entityId);
  const { value, review } = req.body;

  if (!entityType || !entityId) {
    throw new BadRequestError("Missing entity params");
  }

  if (!entityEngagementService.isSupportedEntityType(entityType)) {
    throw new BadRequestError("Unsupported entity type");
  }

  const parsedValue = Number(value);
  if (!Number.isInteger(parsedValue) || parsedValue < 1 || parsedValue > 5) {
    throw new BadRequestError("Rating value must be an integer between 1 and 5");
  }

  try {
    const data = await entityEngagementService.setRating(
      entityType,
      entityId,
      req.user.id,
      parsedValue,
      typeof review === "string" ? review : null,
    );
    return res.status(200).json({ data });
  } catch (error) {
    if ((error as Error).message === "Entity not found") {
      throw new NotFoundError("Entity not found");
    }
    throw error;
  }
};

export const deleteEntityRating = async (
  req: ICustomRequest,
  res: Response,
) => {
  const entityType = asString(req.params.entityType);
  const entityId = asString(req.params.entityId);

  if (!entityType || !entityId) {
    throw new BadRequestError("Missing entity params");
  }

  if (!entityEngagementService.isSupportedEntityType(entityType)) {
    throw new BadRequestError("Unsupported entity type");
  }

  const data = await entityEngagementService.deleteRating(
    entityType,
    entityId,
    req.user.id,
  );
  return res.status(200).json({ data });
};

export const trackEntityView = async (req: ICustomRequest, res: Response) => {
  const entityType = asString(req.params.entityType);
  const entityId = asString(req.params.entityId);

  if (!entityType || !entityId) {
    throw new BadRequestError("Missing entity params");
  }

  if (!entityEngagementService.isSupportedEntityType(entityType)) {
    throw new BadRequestError("Unsupported entity type");
  }

  const data = await entityEngagementService.trackView(entityType, entityId, {
    userId: req.user?.id,
    ip: getViewerIp(req),
    userAgent: req.headers["user-agent"] || null,
  });

  return res.status(200).json({ data });
};
