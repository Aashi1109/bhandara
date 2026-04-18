import { Op, Sequelize, type WhereOptions } from 'sequelize';

import { EAddressEntityType, type EEventStatus, type EEventType } from '@/src/common/definitions/enums';
import type { IPaginationParams, PaginatedResult } from '@/src/common/definitions/types';

import AddressService from '../addresses/service';
import { Event } from '../events/model';
import { buildActiveEventStatusPredicate, deriveEventStatus } from '../events/status';

export interface ISearchFilters {
  eventStatus?: EEventStatus[];
  eventType?: EEventType[];
  location?: {
    latitude: number;
    longitude: number;
    radius: number;
  };
  tags?: string[];
  startDate?: Date;
  endDate?: Date;
  limit?: number;
  next?: string | null;
}

export interface ISearchResult {
  id: string;
  type: 'event';
  title: string;
  description?: string;
  imageUrl?: string;
  metadata: Record<string, any>;
  relevanceScore: number;
  createdAt: Date;
  updatedAt: Date;
}

class SearchService {
  private readonly addressService: AddressService;

  constructor() {
    this.addressService = new AddressService();
  }

  private escapeForLike(value: string): string {
    return value.replace(/'/g, "''").replace(/%/g, '\\%').replace(/_/g, '\\_');
  }

  private encodeCursor(index: number): string {
    return Buffer.from(String(index), 'utf8').toString('base64url');
  }

  private decodeCursor(cursor: string): number {
    const decoded = Number.parseInt(Buffer.from(cursor, 'base64url').toString('utf8'), 10);
    return Number.isFinite(decoded) && decoded >= 0 ? decoded : 0;
  }

  private timestampColumnExpression(field: 'start' | 'end') {
    return field === 'start' ? '"startTime"' : '"endTime"';
  }

  private buildDerivedStatusClause(status: EEventStatus) {
    const escape = Event.sequelize!.escape.bind(Event.sequelize);
    const now = escape(new Date().toISOString());
    const startExpr = this.timestampColumnExpression('start');
    const endExpr = this.timestampColumnExpression('end');
    const activeStatuses = buildActiveEventStatusPredicate();

    switch (status) {
      case 'draft':
        return { isDraft: true, cancelledAt: null };
      case 'cancelled':
        return Sequelize.literal('"cancelledAt" IS NOT NULL');
      case 'upcoming':
        return Sequelize.literal(`(${activeStatuses} AND ${startExpr} > ${now})`);
      case 'ongoing':
        return Sequelize.literal(`(${activeStatuses} AND ${startExpr} <= ${now} AND ${endExpr} > ${now})`);
      case 'completed':
        return Sequelize.literal(`(${activeStatuses} AND ${endExpr} <= ${now})`);
      default:
        return null;
    }
  }

  private buildWhere(query: string, filters: ISearchFilters): WhereOptions {
    const clauses: any[] = [
      {
        [Op.or]: [
          { name: { [Op.iLike]: `%${query}%` } },
          { description: { [Op.iLike]: `%${query}%` } },
          Sequelize.literal(`CAST(COALESCE("tags", '[]'::jsonb) AS TEXT) ILIKE '%${this.escapeForLike(query)}%'`),
        ],
      },
    ];

    if (filters.eventType?.length) {
      clauses.push({ type: { [Op.in]: filters.eventType } });
    }

    if (filters.eventStatus?.length) {
      const statusClauses = filters.eventStatus.map((status) => this.buildDerivedStatusClause(status)).filter(Boolean);
      if (statusClauses.length) {
        clauses.push({ [Op.or]: statusClauses });
      }
    }

    if (filters.tags?.length) {
      const escape = Event.sequelize!.escape.bind(Event.sequelize);
      const tagArray = filters.tags.map((tagId) => escape(tagId)).join(', ');
      clauses.push(Sequelize.literal(`(COALESCE("tags", '[]'::jsonb) ?| ARRAY[${tagArray}])`));
    }

    if (filters.startDate && filters.endDate) {
      const escape = Event.sequelize!.escape.bind(Event.sequelize);
      clauses.push(
        Sequelize.literal(
          `(${this.timestampColumnExpression('start')} >= ${escape(filters.startDate.toISOString())} AND ${this.timestampColumnExpression('start')} <= ${escape(filters.endDate.toISOString())})`,
        ),
      );
    }

    if (
      Number.isFinite(filters.location?.latitude) &&
      Number.isFinite(filters.location?.longitude) &&
      Number.isFinite(filters.location?.radius)
    ) {
      clauses.push(
        this.addressService.buildEntityDistanceClause({
          entityType: EAddressEntityType.Event,
          entityIdColumn: `"Event"."id"`,
          latitude: filters.location!.latitude,
          longitude: filters.location!.longitude,
          radiusKm: filters.location!.radius,
        }),
      );
    }

    return { [Op.and]: clauses };
  }

  async search(
    query: string,
    filters: ISearchFilters = {},
    pagination: Partial<IPaginationParams> = {},
  ): Promise<PaginatedResult<ISearchResult>> {
    const limit = filters.limit || pagination.limit || 20;
    const nextCursor = filters.next || pagination.next || null;
    const startIndex = nextCursor ? this.decodeCursor(nextCursor) : 0;
    const fetchLimit = startIndex + limit;

    const eventResults = await this.searchEvents(query, filters, fetchLimit);
    const items = eventResults.data.slice(startIndex, startIndex + limit);
    const nextIndex = startIndex + items.length;
    const hasNext = nextIndex < eventResults.data.length;

    return {
      items,
      pagination: {
        total: eventResults.total,
        limit,
        hasNext,
        next: hasNext ? this.encodeCursor(nextIndex) : null,
        sortBy: 'updatedAt',
        sortOrder: 'desc',
      },
    };
  }

  private async searchEvents(
    query: string,
    filters: ISearchFilters,
    limit: number,
  ): Promise<{ data: ISearchResult[]; total: number }> {
    const where = this.buildWhere(query, filters);
    const safeQuery = this.escapeForLike(query);
    const count = await Event.count({ where });
    const rows = await Event.findAll({
      attributes: [
        'id',
        'name',
        'type',
        'isDraft',
        'cancelledAt',
        'startTime',
        'endTime',
        'media',
        'tags',
        'description',
        'createdAt',
        'updatedAt',
      ],
      where,
      limit,
      order: [
        [
          Sequelize.literal(`CASE
            WHEN name ILIKE '${safeQuery}%' THEN 1
            WHEN name ILIKE '%${safeQuery}%' THEN 2
            WHEN description ILIKE '%${safeQuery}%' THEN 3
            ELSE 4
          END`),
          'ASC',
        ],
        ['createdAt', 'DESC'],
        ['id', 'DESC'],
      ],
    });
    const addressMap = await this.addressService.getByEntities(
      EAddressEntityType.Event,
      rows.map((event) => event.id),
    );

    const results = rows.map((event) => {
      const previewImage =
        event.media?.find((item: any) => item.type === 'image')?.publicUrl ||
        event.media?.find((item: any) => item.type === 'image')?.url ||
        null;
      const resolvedStatus = deriveEventStatus(event as any);
      const location = this.addressService.toLocation(addressMap[event.id]);

      return {
        id: event.id,
        type: 'event' as const,
        title: event.name,
        description:
          event.description && event.description.length > 200
            ? `${event.description.slice(0, 200)}...`
            : event.description,
        imageUrl: previewImage ?? undefined,
        metadata: {
          status: resolvedStatus,
          type: event.type,
          location,
          startTime: event.startTime,
          endTime: event.endTime,
          createdAt: event.createdAt.toISOString(),
        },
        relevanceScore: this.calculateEventRelevance(event, query),
        createdAt: event.createdAt,
        updatedAt: event.updatedAt,
      };
    });

    results.sort((a, b) => {
      if (Math.abs(a.relevanceScore - b.relevanceScore) < 0.1) {
        return b.createdAt.getTime() - a.createdAt.getTime();
      }
      return b.relevanceScore - a.relevanceScore;
    });

    return { data: results, total: count };
  }

  private calculateEventRelevance(event: any, query: string): number {
    let score = 0;
    const normalizedQuery = query.toLowerCase();

    if (event.name.toLowerCase() === normalizedQuery) {
      score += 10;
    } else if (event.name.toLowerCase().startsWith(normalizedQuery)) {
      score += 8;
    } else if (event.name.toLowerCase().includes(normalizedQuery)) {
      score += 6;
    }

    if (event.description?.toLowerCase().includes(normalizedQuery)) {
      score += 3;
    }

    const tagsText = JSON.stringify(event.tags ?? []).toLowerCase();
    if (tagsText.includes(normalizedQuery)) {
      score += 2;
    }

    const daysSinceCreation = (Date.now() - new Date(event.createdAt).getTime()) / (1000 * 60 * 60 * 24);
    if (daysSinceCreation < 7) score += 2;
    else if (daysSinceCreation < 30) score += 1;

    return score;
  }

  async getSuggestions(query: string, limit: number = 5): Promise<string[]> {
    const rows = await Event.findAll({
      attributes: ['name'],
      where: {
        name: {
          [Op.iLike]: `%${query}%`,
        },
      },
      order: [['createdAt', 'DESC']],
      limit,
    });

    return [...new Set(rows.map((event) => event.name))].slice(0, limit);
  }
}

export default new SearchService();
