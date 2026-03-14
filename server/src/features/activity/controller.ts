import type { ICustomRequest, IRequestPagination } from "@/definitions/types";
import type { Response } from "express";
import ActivityService from "./service";
import { NotFoundError } from "@/exceptions";

const activityService = new ActivityService();

export const getUserActivity = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const id = req.params.id as string;
  const { type, includePrivate } = req.query;

  const types = type
    ? String(type)
        .split(",")
        .map((t) => t.trim())
        .filter(Boolean)
    : [];

  const canIncludePrivate = req.user.id === id && includePrivate === "true";

  const data = await activityService.getUserActivity(id, req.pagination, {
    includePrivate: canIncludePrivate,
    types,
  });

  return res.status(200).json({ data, error: null });
};

export const getMyUpdates = async (
  req: ICustomRequest & IRequestPagination,
  res: Response
) => {
  const { unreadOnly, type } = req.query;

  const types = type
    ? String(type)
        .split(",")
        .map((t) => t.trim())
        .filter(Boolean)
    : [];

  const data = await activityService.getUserUpdates(req.user.id, req.pagination, {
    unreadOnly: unreadOnly === "true",
    types,
  });

  return res.status(200).json({ data, error: null });
};

export const markUpdateAsRead = async (req: ICustomRequest, res: Response) => {
  const activityId = req.params.activityId as string;
  const data = await activityService.markAsRead(activityId, req.user.id);

  if (!data) throw new NotFoundError("Activity not found");

  return res.status(200).json({ data, error: null });
};

export const markAllUpdatesAsRead = async (
  req: ICustomRequest,
  res: Response
) => {
  const data = await activityService.markAllAsRead(req.user.id);
  return res.status(200).json({ data, error: null });
};
