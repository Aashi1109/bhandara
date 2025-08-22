import { Op, Sequelize } from "sequelize";
import { Event } from "../events/model";
import { User } from "../users/model";
import { Tag } from "../tags/model";
import { IPaginationParams } from "@definitions/types";
import { EEventStatus, EEventType } from "@definitions/enums";
import { getDBConnection } from "@connections/db";

const sequelize = getDBConnection();

export interface ISearchFilters {
  types?: ('event' | 'user' | 'tag')[];
  eventStatus?: EEventStatus[];
  eventType?: EEventType[];
  dateRange?: {
    start: Date;
    end: Date;
  };
  location?: {
    latitude: number;
    longitude: number;
    radius: number; // in kilometers
  };
  tags?: string[];
  limit?: number;
  offset?: number;
}

export interface ISearchResult {
  id: string;
  type: 'event' | 'user' | 'tag';
  title: string;
  description?: string;
  imageUrl?: string;
  metadata: Record<string, any>;
  relevanceScore: number;
  createdAt: Date;
}

class SearchService {
  /**
   * Perform a comprehensive search across events, users, and tags
   */
  async search(
    query: string,
    filters: ISearchFilters = {},
    pagination: Partial<IPaginationParams> = {}
  ): Promise<{
    data: ISearchResult[];
    pagination: {
      total: number;
      page: number;
      limit: number;
      hasNext: boolean;
    };
  }> {
    const limit = filters.limit || pagination.limit || 20;
    const offset = filters.offset || ((pagination.page || 1) - 1) * limit;
    
    const results: ISearchResult[] = [];
    let totalCount = 0;

    // Search events
    if (!filters.types || filters.types.includes('event')) {
      const eventResults = await this.searchEvents(query, filters, limit, offset);
      results.push(...eventResults.data);
      totalCount += eventResults.total;
    }

    // Search users
    if (!filters.types || filters.types.includes('user')) {
      const userResults = await this.searchUsers(query, filters, limit, offset);
      results.push(...userResults.data);
      totalCount += userResults.total;
    }

    // Search tags
    if (!filters.types || filters.types.includes('tag')) {
      const tagResults = await this.searchTags(query, filters, limit, offset);
      results.push(...tagResults.data);
      totalCount += tagResults.total;
    }

    // Sort by relevance score and recency
    results.sort((a, b) => {
      if (Math.abs(a.relevanceScore - b.relevanceScore) < 0.1) {
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      }
      return b.relevanceScore - a.relevanceScore;
    });

    return {
      data: results.slice(0, limit),
      pagination: {
        total: totalCount,
        page: Math.floor(offset / limit) + 1,
        limit,
        hasNext: results.length > limit,
      },
    };
  }

  /**
   * Search events with advanced filtering
   */
  private async searchEvents(
    query: string,
    filters: ISearchFilters,
    limit: number,
    offset: number
  ): Promise<{ data: ISearchResult[]; total: number }> {
    const whereClause: any = {
      [Op.or]: [
        {
          name: {
            [Op.iLike]: `%${query}%`,
          },
        },
        {
          description: {
            [Op.iLike]: `%${query}%`,
          },
        },
        {
          tags: {
            [Op.overlap]: [query],
          },
        },
      ],
    };

    // Apply filters
    if (filters.eventStatus?.length) {
      whereClause.status = { [Op.in]: filters.eventStatus };
    }

    if (filters.eventType?.length) {
      whereClause.type = { [Op.in]: filters.eventType };
    }

    if (filters.dateRange) {
      whereClause['timings.startDate'] = {
        [Op.between]: [filters.dateRange.start, filters.dateRange.end],
      };
    }

    if (filters.location) {
      // Add location-based filtering using PostGIS or similar
      // This is a simplified version - you might want to use proper geospatial queries
      whereClause['location.latitude'] = {
        [Op.between]: [
          filters.location.latitude - filters.location.radius / 111,
          filters.location.latitude + filters.location.radius / 111,
        ],
      };
      whereClause['location.longitude'] = {
        [Op.between]: [
          filters.location.longitude - filters.location.radius / (111 * Math.cos(filters.location.latitude * Math.PI / 180)),
          filters.location.longitude + filters.location.radius / (111 * Math.cos(filters.location.latitude * Math.PI / 180)),
        ],
      };
    }

    const { count, rows } = await Event.findAndCountAll({
      where: whereClause,
      limit,
      offset,
      order: [
        [Sequelize.literal(`CASE 
          WHEN name ILIKE '${query}%' THEN 1
          WHEN name ILIKE '%${query}%' THEN 2
          WHEN description ILIKE '%${query}%' THEN 3
          ELSE 4
        END`), 'ASC'],
        ['createdAt', 'DESC'],
      ],
      include: [
        {
          model: sequelize.models.User,
          as: 'creator',
          attributes: ['id', 'username', 'avatar'],
        },
      ],
    });

    const results: ISearchResult[] = rows.map((event) => {
      const relevanceScore = this.calculateEventRelevance(event, query);
      const previewImage = event.media?.find((m: any) => m.type === 'image')?.publicUrl;

      return {
        id: event.id,
        type: 'event' as const,
        title: event.name,
        description: event.description,
        imageUrl: previewImage,
        metadata: {
          status: event.status,
          type: event.type,
          location: event.location,
          timings: event.timings,
          capacity: event.capacity,
          participants: event.participants?.length || 0,
          creator: event.creator,
        },
        relevanceScore,
        createdAt: event.createdAt,
      };
    });

    return { data: results, total: count };
  }

  /**
   * Search users
   */
  private async searchUsers(
    query: string,
    filters: ISearchFilters,
    limit: number,
    offset: number
  ): Promise<{ data: ISearchResult[]; total: number }> {
    const whereClause = {
      [Op.or]: [
        {
          username: {
            [Op.iLike]: `%${query}%`,
          },
        },
        {
          fullName: {
            [Op.iLike]: `%${query}%`,
          },
        },
        {
          bio: {
            [Op.iLike]: `%${query}%`,
          },
        },
      ],
    };

    const { count, rows } = await User.findAndCountAll({
      where: whereClause,
      limit,
      offset,
      order: [
        [Sequelize.literal(`CASE 
          WHEN username ILIKE '${query}%' THEN 1
          WHEN username ILIKE '%${query}%' THEN 2
          WHEN full_name ILIKE '%${query}%' THEN 3
          ELSE 4
        END`), 'ASC'],
        ['createdAt', 'DESC'],
      ],
    });

    const results: ISearchResult[] = rows.map((user) => {
      const relevanceScore = this.calculateUserRelevance(user, query);

      return {
        id: user.id,
        type: 'user' as const,
        title: user.username || user.name,
        description: user.meta?.bio || '',
        imageUrl: user.profilePic?.url || null,
        metadata: {
          fullName: user.name,
          email: user.email,
          isVerified: user.isVerified,
          followers: 0, // TODO: Implement followers/following system
          following: 0,
        },
        relevanceScore,
        createdAt: user.createdAt,
      };
    });

    return { data: results, total: count };
  }

  /**
   * Search tags
   */
  private async searchTags(
    query: string,
    filters: ISearchFilters,
    limit: number,
    offset: number
  ): Promise<{ data: ISearchResult[]; total: number }> {
    const whereClause = {
      [Op.or]: [
        {
          name: {
            [Op.iLike]: `%${query}%`,
          },
        },
        {
          description: {
            [Op.iLike]: `%${query}%`,
          },
        },
      ],
    };

    const { count, rows } = await Tag.findAndCountAll({
      where: whereClause,
      limit,
      offset,
      order: [
        [Sequelize.literal(`CASE 
          WHEN name ILIKE '${query}%' THEN 1
          WHEN name ILIKE '%${query}%' THEN 2
          ELSE 3
        END`), 'ASC'],
        ['createdAt', 'DESC'],
      ],
    });

    const results: ISearchResult[] = rows.map((tag) => {
      const relevanceScore = this.calculateTagRelevance(tag, query);

      return {
        id: tag.id,
        type: 'tag' as const,
        title: tag.name,
        description: tag.description,
        imageUrl: tag.icon,
        metadata: {
          color: tag.color,
          usageCount: 0, // TODO: Implement usage count tracking
        },
        relevanceScore,
        createdAt: tag.createdAt,
      };
    });

    return { data: results, total: count };
  }

  /**
   * Calculate relevance score for events
   */
  private calculateEventRelevance(event: any, query: string): number {
    let score = 0;
    const queryLower = query.toLowerCase();

    // Exact name match
    if (event.name.toLowerCase() === queryLower) {
      score += 10;
    }
    // Name starts with query
    else if (event.name.toLowerCase().startsWith(queryLower)) {
      score += 8;
    }
    // Name contains query
    else if (event.name.toLowerCase().includes(queryLower)) {
      score += 6;
    }

    // Description contains query
    if (event.description?.toLowerCase().includes(queryLower)) {
      score += 3;
    }

    // Tag match
    if (event.tags?.some((tag: string) => tag.toLowerCase().includes(queryLower))) {
      score += 4;
    }

    // Recency bonus
    const daysSinceCreation = (Date.now() - new Date(event.createdAt).getTime()) / (1000 * 60 * 60 * 24);
    if (daysSinceCreation < 7) score += 2;
    else if (daysSinceCreation < 30) score += 1;

    // Popularity bonus
    if (event.participants?.length > 10) score += 1;
    if (event.participants?.length > 50) score += 1;

    return score;
  }

  /**
   * Calculate relevance score for users
   */
  private calculateUserRelevance(user: any, query: string): number {
    let score = 0;
    const queryLower = query.toLowerCase();

    // Exact username match
    if (user.username.toLowerCase() === queryLower) {
      score += 10;
    }
    // Username starts with query
    else if (user.username.toLowerCase().startsWith(queryLower)) {
      score += 8;
    }
    // Username contains query
    else if (user.username.toLowerCase().includes(queryLower)) {
      score += 6;
    }

    // Full name contains query
    if (user.fullName?.toLowerCase().includes(queryLower)) {
      score += 4;
    }

    // Bio contains query
    if (user.bio?.toLowerCase().includes(queryLower)) {
      score += 2;
    }

    // Verification bonus
    if (user.isVerified) score += 1;

    // Popularity bonus
    if (user.followers?.length > 100) score += 1;
    if (user.followers?.length > 1000) score += 1;

    return score;
  }

  /**
   * Calculate relevance score for tags
   */
  private calculateTagRelevance(tag: any, query: string): number {
    let score = 0;
    const queryLower = query.toLowerCase();

    // Exact name match
    if (tag.name.toLowerCase() === queryLower) {
      score += 10;
    }
    // Name starts with query
    else if (tag.name.toLowerCase().startsWith(queryLower)) {
      score += 8;
    }
    // Name contains query
    else if (tag.name.toLowerCase().includes(queryLower)) {
      score += 6;
    }

    // Description contains query
    if (tag.description?.toLowerCase().includes(queryLower)) {
      score += 3;
    }

    // Usage bonus
    if (tag.usageCount > 10) score += 1;
    if (tag.usageCount > 100) score += 1;

    return score;
  }

  /**
   * Get search suggestions based on recent searches and popular items
   */
  async getSuggestions(query: string, limit: number = 5): Promise<string[]> {
    const suggestions: string[] = [];

    // Get popular event names
    const popularEvents = await Event.findAll({
      attributes: ['name'],
      order: [['createdAt', 'DESC']],
      limit: Math.ceil(limit / 2),
    });

    // Get popular usernames
    const popularUsers = await User.findAll({
      attributes: ['username'],
      order: [['createdAt', 'DESC']],
      limit: Math.ceil(limit / 2),
    });

    // Get popular tags
    const popularTags = await Tag.findAll({
      attributes: ['name'],
      order: [['usageCount', 'DESC']],
      limit: Math.ceil(limit / 2),
    });

    suggestions.push(...popularEvents.map(e => e.name));
    suggestions.push(...popularUsers.map(u => u.username));
    suggestions.push(...popularTags.map(t => t.name));

    // Filter and return unique suggestions that match the query
    return [...new Set(suggestions)]
      .filter(suggestion => suggestion.toLowerCase().includes(query.toLowerCase()))
      .slice(0, limit);
  }
}

export default new SearchService();