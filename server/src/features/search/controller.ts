import type { Request, Response } from 'express';
import SearchService, { type ISearchFilters } from './service';
import { validateSearchRequest } from './validation';
import logger from '@/logger';

class SearchController {
  /**
   * Perform a search across all searchable entities
   */
  async search(req: Request, res: Response) {
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

      const { query, filters, next = null, limit = 20 } = value;
      const parsedLimit = Number(limit);

      if (!query || query.trim().length < 2) {
        return res.status(400).json({
          data: null,
          error: {
            message: 'Search query must be at least 2 characters long',
            status: 400,
          },
        });
      }

      const searchFilters: ISearchFilters = {
        types: filters?.types,
        eventStatus: filters?.eventStatus,
        eventType: filters?.eventType,
        dateRange: filters?.dateRange
          ? {
              start: new Date(filters.dateRange.start),
              end: new Date(filters.dateRange.end),
            }
          : undefined,
        location: filters?.location
          ? {
              latitude: parseFloat(filters.location.latitude),
              longitude: parseFloat(filters.location.longitude),
              radius: parseFloat(filters.location.radius),
            }
          : undefined,
        tags: filters?.tags,
        limit: parsedLimit,
        next: next ? String(next) : null,
      };

      const result = await SearchService.search(query.trim(), searchFilters, {
        limit: parsedLimit,
        next: next ? String(next) : null,
      });

      logger.info(`Search performed: "${query}" returned ${result.items.length} results`);

      return res.status(200).json({
        data: result,
        });
    } catch (error: any) {
      logger.error('Search error:', error);
      return res.status(500).json({
        data: null,
        error: process.env.NODE_ENV === 'development' ? error.message : 'An error occurred while performing the search',
      });
    }
  }

  /**
   * Get search suggestions
   */
  async getSuggestions(req: Request, res: Response) {
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

      const suggestions = await SearchService.getSuggestions(query.trim(), parseInt(limit as string));

      return res.status(200).json({
        data: suggestions,
        });
    } catch (error: any) {
      logger.error('Get suggestions error:', error);
      return res.status(500).json({
        data: null,
        error: process.env.NODE_ENV === 'development' ? error.message : 'An error occurred while getting suggestions',
      });
    }
  }

  /**
   * Get search filters and options
   */
  async getSearchOptions(req: Request, res: Response) {
    try {
      // Return available search filters and options
      const options = {
        types: [
          { value: 'event', label: 'Events' },
          { value: 'user', label: 'Users' },
          { value: 'tag', label: 'Tags' },
        ],
        eventStatus: [
          { value: 'draft', label: 'Draft' },
          { value: 'published', label: 'Published' },
          { value: 'ongoing', label: 'Ongoing' },
          { value: 'completed', label: 'Completed' },
          { value: 'cancelled', label: 'Cancelled' },
        ],
        eventType: [
          { value: 'conference', label: 'Conference' },
          { value: 'workshop', label: 'Workshop' },
          { value: 'meetup', label: 'Meetup' },
          { value: 'webinar', label: 'Webinar' },
          { value: 'hackathon', label: 'Hackathon' },
          { value: 'other', label: 'Other' },
        ],
      };

      return res.status(200).json({
        data: options,
        });
    } catch (error: any) {
      logger.error('Get search options error:', error);
      return res.status(500).json({
        data: null,
        error:
          process.env.NODE_ENV === 'development' ? error.message : 'An error occurred while getting search options',
      });
    }
  }
}

export default new SearchController();
