import { Request, Response } from "express";
import SearchService, { ISearchFilters } from "./service";
import { validateSearchRequest } from "./validation";
import logger from "@logger";

class SearchController {
  /**
   * Perform a search across all searchable entities
   */
  async search(req: Request, res: Response) {
    try {
      const { error, value } = validateSearchRequest(req.query);
      if (error) {
        return res.status(400).json({
          success: false,
          message: "Invalid search parameters",
          errors: error.details,
        });
      }

      const { query, filters, page = 1, limit = 20 } = value;

      if (!query || query.trim().length < 2) {
        return res.status(400).json({
          success: false,
          message: "Search query must be at least 2 characters long",
        });
      }

      const searchFilters: ISearchFilters = {
        types: filters?.types,
        eventStatus: filters?.eventStatus,
        eventType: filters?.eventType,
        dateRange: filters?.dateRange ? {
          start: new Date(filters.dateRange.start),
          end: new Date(filters.dateRange.end),
        } : undefined,
        location: filters?.location ? {
          latitude: parseFloat(filters.location.latitude),
          longitude: parseFloat(filters.location.longitude),
          radius: parseFloat(filters.location.radius),
        } : undefined,
        tags: filters?.tags,
        limit: parseInt(limit),
        offset: (parseInt(page) - 1) * parseInt(limit),
      };

      const result = await SearchService.search(query.trim(), searchFilters, {
        page: parseInt(page),
        limit: parseInt(limit),
      });

      logger.info(`Search performed: "${query}" returned ${result.data.length} results`);

      return res.status(200).json({
        success: true,
        data: result.data,
        pagination: result.pagination,
      });
    } catch (error: any) {
      logger.error("Search error:", error);
      return res.status(500).json({
        success: false,
        message: "An error occurred while performing the search",
        error: process.env.NODE_ENV === "development" ? error.message : undefined,
      });
    }
  }

  /**
   * Get search suggestions
   */
  async getSuggestions(req: Request, res: Response) {
    try {
      const { query, limit = 5 } = req.query;

      if (!query || typeof query !== "string" || query.trim().length < 1) {
        return res.status(400).json({
          success: false,
          message: "Query parameter is required",
        });
      }

      const suggestions = await SearchService.getSuggestions(
        query.trim(),
        parseInt(limit as string)
      );

      return res.status(200).json({
        success: true,
        data: suggestions,
      });
    } catch (error: any) {
      logger.error("Get suggestions error:", error);
      return res.status(500).json({
        success: false,
        message: "An error occurred while getting suggestions",
        error: process.env.NODE_ENV === "development" ? error.message : undefined,
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
          { value: "event", label: "Events" },
          { value: "user", label: "Users" },
          { value: "tag", label: "Tags" },
        ],
        eventStatus: [
          { value: "draft", label: "Draft" },
          { value: "published", label: "Published" },
          { value: "ongoing", label: "Ongoing" },
          { value: "completed", label: "Completed" },
          { value: "cancelled", label: "Cancelled" },
        ],
        eventType: [
          { value: "conference", label: "Conference" },
          { value: "workshop", label: "Workshop" },
          { value: "meetup", label: "Meetup" },
          { value: "webinar", label: "Webinar" },
          { value: "hackathon", label: "Hackathon" },
          { value: "other", label: "Other" },
        ],
      };

      return res.status(200).json({
        success: true,
        data: options,
      });
    } catch (error: any) {
      logger.error("Get search options error:", error);
      return res.status(500).json({
        success: false,
        message: "An error occurred while getting search options",
        error: process.env.NODE_ENV === "development" ? error.message : undefined,
      });
    }
  }
}

export default new SearchController();