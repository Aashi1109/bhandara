import type { Request, Response } from 'express';

import { EEventStatus, EEventType } from '@/definitions/enums';
import { BadRequestError } from '@/exceptions';
import logger from '@/logger';

import SearchService, { type ISearchFilters } from './service';
import { validateSearchRequest } from './validation';

class SearchController {
  search = async (req: Request, res: Response) => {
    try {
      const { error, value } = validateSearchRequest(req.query);
      if (error) {
        return res.status(400).json({
          data: null,
          error: {
            message: 'Invalid search parameters',
            details: error.details,
            status: 400,
          },
        });
      }

      const { query, status, type, datePreset, latitude, longitude, radiusKm, tagIds, next = null, limit = 20 } = value;

      if (!query || query.trim().length < 2) {
        return res.status(400).json({
          data: null,
          error: {
            message: 'Search query must be at least 2 characters long',
            status: 400,
          },
        });
      }

      const parsedStatuses = this.parseStatuses(status);
      const parsedTypes = this.parseTypes(type);
      const { startDate, endDate } = this.resolveDatePreset(datePreset);

      const parsedLatitude =
        typeof latitude === 'number'
          ? latitude
          : latitude !== null && latitude !== undefined
            ? Number(latitude)
            : undefined;
      const parsedLongitude =
        typeof longitude === 'number'
          ? longitude
          : longitude !== null && longitude !== undefined
            ? Number(longitude)
            : undefined;
      const parsedRadiusKm =
        typeof radiusKm === 'number'
          ? radiusKm
          : radiusKm !== null && radiusKm !== undefined
            ? Number(radiusKm)
            : undefined;

      if (
        (parsedLatitude !== null && parsedLatitude !== undefined && !Number.isFinite(parsedLatitude)) ||
        (parsedLongitude !== null && parsedLongitude !== undefined && !Number.isFinite(parsedLongitude)) ||
        (parsedRadiusKm !== null &&
          parsedRadiusKm !== undefined &&
          (!Number.isFinite(parsedRadiusKm) || parsedRadiusKm <= 0))
      ) {
        return res.status(400).json({
          data: null,
          error: {
            message: 'Invalid location filter',
            status: 400,
          },
        });
      }

      const searchFilters: ISearchFilters = {
        eventStatus: parsedStatuses,
        eventType: parsedTypes,
        location:
          parsedLatitude !== null &&
          parsedLatitude !== undefined &&
          parsedLongitude !== null &&
          parsedLongitude !== undefined &&
          parsedRadiusKm !== null &&
          parsedRadiusKm !== undefined
            ? {
                latitude: parsedLatitude,
                longitude: parsedLongitude,
                radius: parsedRadiusKm,
              }
            : undefined,
        tags:
          typeof tagIds === 'string' && tagIds.length > 0
            ? tagIds
                .split(',')
                .map((item) => item.trim())
                .filter(Boolean)
            : undefined,
        startDate,
        endDate,
        limit: Number(limit),
        next: next ? String(next) : null,
      };

      const result = await SearchService.search(query.trim(), searchFilters, {
        limit: Number(limit),
        next: next ? String(next) : null,
      });

      logger.info(`Event search performed: "${query}" returned ${result.items.length} results`);

      return res.status(200).json({ data: result });
    } catch (error: any) {
      if (error instanceof BadRequestError || error?.status === 400) {
        return res.status(400).json({
          data: null,
          error: {
            message: error.message,
            status: 400,
          },
        });
      }

      logger.error('Search error:', error);
      return res.status(500).json({
        data: null,
        error: process.env.NODE_ENV === 'development' ? error.message : 'An error occurred while performing the search',
      });
    }
  };

  getSuggestions = async (req: Request, res: Response) => {
    try {
      const { query, limit = 5 } = req.query;

      if (!query || typeof query !== 'string' || query.trim().length < 1) {
        return res.status(400).json({
          data: null,
          error: {
            message: 'Query parameter is required',
            status: 400,
          },
        });
      }

      const suggestions = await SearchService.getSuggestions(query.trim(), parseInt(limit as string, 10));

      return res.status(200).json({ data: suggestions });
    } catch (error: any) {
      logger.error('Get suggestions error:', error);
      return res.status(500).json({
        data: null,
        error: process.env.NODE_ENV === 'development' ? error.message : 'An error occurred while getting suggestions',
      });
    }
  };

  getSearchOptions = async (req: Request, res: Response) => {
    try {
      const options = {
        types: [{ value: 'event', label: 'Events' }],
        eventStatus: [
          { value: 'upcoming', label: 'Upcoming' },
          { value: 'ongoing', label: 'Ongoing' },
          { value: 'completed', label: 'Completed' },
          { value: 'cancelled', label: 'Cancelled' },
        ],
        eventType: [
          { value: 'organized', label: 'Organized' },
          { value: 'custom', label: 'Custom' },
        ],
      };

      return res.status(200).json({ data: options });
    } catch (error: any) {
      logger.error('Get search options error:', error);
      return res.status(500).json({
        data: null,
        error:
          process.env.NODE_ENV === 'development' ? error.message : 'An error occurred while getting search options',
      });
    }
  };

  private parseStatuses(value: unknown): EEventStatus[] | undefined {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return undefined;
    }

    const items = value
      .split(',')
      .map((item) => item.trim() as EEventStatus)
      .filter(Boolean);

    if (items.some((item) => !Object.values(EEventStatus).includes(item))) {
      throw new BadRequestError('Invalid event status filter');
    }

    return items;
  }

  private parseTypes(value: unknown): EEventType[] | undefined {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return undefined;
    }

    const items = value
      .split(',')
      .map((item) => item.trim() as EEventType)
      .filter(Boolean);

    if (items.some((item) => !Object.values(EEventType).includes(item))) {
      throw new BadRequestError('Invalid event type filter');
    }

    return items;
  }

  private resolveDatePreset(value: unknown) {
    const normalized = typeof value === 'string' ? value.trim().toLowerCase() : null;
    if (!normalized || normalized === 'anytime') {
      return { startDate: undefined, endDate: undefined };
    }

    const now = new Date();
    if (normalized === 'today') {
      return {
        startDate: new Date(now.getFullYear(), now.getMonth(), now.getDate()),
        endDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, -1),
      };
    }

    if (normalized === 'this_week') {
      const startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      startDate.setDate(startDate.getDate() - ((startDate.getDay() + 6) % 7));
      const endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 7);
      endDate.setMilliseconds(endDate.getMilliseconds() - 1);
      return { startDate, endDate };
    }

    if (normalized === 'this_month') {
      return {
        startDate: new Date(now.getFullYear(), now.getMonth(), 1),
        endDate: new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0, -1),
      };
    }

    throw new BadRequestError('Invalid date preset filter');
  }
}

export default new SearchController();
