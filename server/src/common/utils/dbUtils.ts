import { type FindOptions, type Model, type ModelStatic, Op, type WhereOptions } from 'sequelize';
import type { IPaginationParams, PaginatedResult } from '@/common/definitions/types';

/**
 * Retrieve records with cursor-based pagination only.
 */
export interface PaginationCursorPayload {
  sortValue: string;
}

const toCursorDateValue = (value: string) => new Date(value);

export function encodePaginationCursor(sortValue: Date | string): string {
  const normalizedSortValue = sortValue instanceof Date ? sortValue.toISOString() : String(sortValue);
  return Buffer.from(JSON.stringify({ sortValue: normalizedSortValue } satisfies PaginationCursorPayload)).toString(
    'base64url',
  );
}

export function decodePaginationCursor(cursor: string | null | undefined): PaginationCursorPayload | null {
  if (!cursor) {
    return null;
  }

  try {
    const decoded = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as Partial<PaginationCursorPayload>;
    if (!decoded.sortValue) {
      return null;
    }
    return { sortValue: decoded.sortValue };
  } catch {
    return null;
  }
}

export function buildCursorPaginationWhere(
  existingWhere: WhereOptions | undefined,
  cursor: PaginationCursorPayload | null,
  sortBy: IPaginationParams['sortBy'],
  sortOrder: IPaginationParams['sortOrder'],
): WhereOptions | undefined {
  if (!cursor) {
    return existingWhere;
  }

  const operator = sortOrder === 'asc' ? Op.gt : Op.lt;
  const sortValue =
    sortBy === 'createdAt' || sortBy === 'updatedAt' ? toCursorDateValue(cursor.sortValue) : cursor.sortValue;

  const cursorWhere: WhereOptions = {
    [sortBy]: { [operator]: sortValue },
  };

  if (!existingWhere) {
    return cursorWhere;
  }

  return {
    [Op.and]: [existingWhere, cursorWhere],
  };
}

export async function findAllWithPagination<T extends Model>(
  model: ModelStatic<T>,
  findOptions: FindOptions = {},
  pagination: Partial<IPaginationParams> = {},
  select?: string,
  modifyOptions?: (opts: FindOptions) => FindOptions,
): Promise<PaginatedResult<T>> {
  const { limit = 10, next = null, sortBy = 'createdAt', sortOrder = 'desc' } = pagination;

  const _pagination = {
    limit: limit ?? 10,
    next: next ?? null,
    sortBy: sortBy ?? 'createdAt',
    sortOrder: sortOrder ?? 'desc',
  };
  const cursor = decodePaginationCursor(_pagination.next);
  const upperSortOrder = _pagination.sortOrder.toUpperCase();

  // Start with the provided findOptions and merge pagination logic
  const options: FindOptions = {
    raw: true,
    ...findOptions,
    order: findOptions.order || [
      [_pagination.sortBy, upperSortOrder],
      ['id', upperSortOrder],
    ],
    limit: _pagination.limit + 1,
  };

  // Select specific fields
  if (select) {
    options.attributes = select.split(',').map((s) => s.trim());
  }

  if (cursor) {
    options.where = buildCursorPaginationWhere(findOptions.where, cursor, _pagination.sortBy, _pagination.sortOrder);
  }

  // Allow user-defined modification
  if (modifyOptions) {
    Object.assign(options, modifyOptions(options));
  }

  const { rows, count } = await model.findAndCountAll(options);
  const normalizedRows = rows.slice(0, _pagination.limit) as T[];
  const hasNext = rows.length > _pagination.limit;

  const paginationResult = {
    limit: _pagination.limit,
    total: count,
    hasNext,
    next:
      hasNext && normalizedRows.length
        ? encodePaginationCursor(
            (normalizedRows[normalizedRows.length - 1] as any)[_pagination.sortBy] as Date | string,
          )
        : null,
    sortBy: _pagination.sortBy,
    sortOrder: _pagination.sortOrder,
  } as IPaginationParams;

  const items = normalizedRows;

  return { items, pagination: paginationResult };
}
