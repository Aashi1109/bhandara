import type { IRequestPagination } from "@/definitions/types";
import logger from "@/logger";
import type { NextFunction, Response } from "express";

const paginationParser = (
  req: IRequestPagination,
  res: Response,
  next: NextFunction
) => {
  const {
    limit,
    sortBy,
    sortOrder,
    next: _next,
    startDate,
    endDate,
  } = req.query;
  const parsedLimit = +(limit ?? 10);
  const parsedSortBy =
    sortBy !== "createdAt" && sortBy !== "updatedAt" ? "createdAt" : sortBy;

  const parsedSortOrder =
    sortOrder !== "asc" && sortOrder !== "desc" ? "desc" : sortOrder;

  let parsedStartDate = startDate ? new Date(startDate as string) : null;
  let parsedEndDate = endDate ? new Date(endDate as string) : null;

  // Set invalid dates to null
  if (startDate && parsedStartDate?.toString() === "Invalid Date") {
    logger.warn(`Invalid startDate format: ${startDate}, setting to null`);
    parsedStartDate = null;
  }
  if (endDate && parsedEndDate?.toString() === "Invalid Date") {
    logger.warn(`Invalid endDate format: ${endDate}, setting to null`);
    parsedEndDate = null;
  }

  // add parsed pagination parameters to request object
  req.pagination = {
    limit: parsedLimit,
    sortBy: parsedSortBy,
    sortOrder: parsedSortOrder,
    startDate: parsedStartDate,
    endDate: parsedEndDate,
    next: _next as string | null,
  };

  return next();
};

export default paginationParser;
