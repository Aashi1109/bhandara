import { FindOptions, Model, ModelStatic, Op, Transaction } from "sequelize";
import { IPaginationParams } from "@/definitions/types";
import { getDBConnection } from "@connections/db";
import logger from "@logger";
import { NotFoundError } from "@exceptions";

export interface PaginatedResult<T> {
  items: T[];
  pagination: IPaginationParams;
}

/**
 * Retrieve records with pagination, supporting both cursor and offset modes.
 */
export async function findAllWithPagination<T extends Model>(
  model: ModelStatic<T>,
  where: Record<string, any> = {},
  pagination: Partial<IPaginationParams> = {},
  select?: string,
  modifyOptions?: (opts: FindOptions) => FindOptions
): Promise<PaginatedResult<T>> {
  const {
    limit = 10,
    page = 1,
    next = null,
    sortBy = "createdAt",
    sortOrder = "desc",
  } = pagination;

  const _pagination = {
    limit: limit ?? 10,
    page: page ?? 1,
    next: next ?? null,
    sortBy: sortBy ?? "createdAt",
    sortOrder: sortOrder ?? "desc",
  };

  const isCursorMode = !!next;
  const effectiveLimit = limit + 1;

  const options: FindOptions = {
    raw: true,
    where: { ...where },
    order: [[_pagination.sortBy, _pagination.sortOrder.toUpperCase()]],
    limit: effectiveLimit,
  };

  // Select specific fields
  if (select) {
    options.attributes = select.split(",").map((s) => s.trim());
  }

  // Cursor-based pagination
  if (isCursorMode) {
    (options.where as any)[_pagination.sortBy] = {
      [_pagination.sortOrder === "asc" ? Op.gt : Op.lt]: _pagination.next,
    };
  } else {
    // Offset-based pagination
    options.offset = (_pagination.page - 1) * _pagination.limit;
  }

  // Allow user-defined modification
  if (modifyOptions) {
    Object.assign(options, modifyOptions(options));
  }

  const { rows, count } = await model.findAndCountAll(options);

  const hasNext = rows.length > _pagination.limit;
  const items = hasNext
    ? (rows.slice(0, _pagination.limit) as T[])
    : (rows as T[]);

  const paginationResult = {
    limit,
    total: count,
  } as IPaginationParams;

  if (isCursorMode) {
    paginationResult.next = hasNext
      ? rows[_pagination.limit][_pagination.sortBy]
      : null;
  } else {
    paginationResult.page = _pagination.page;
    paginationResult.hasNext = hasNext;
    paginationResult.next = hasNext
      ? rows[_pagination.limit - 1][_pagination.sortBy]
      : null;
  }

  return { items, pagination: paginationResult };
}

/** Find a record by its primary key. */
export async function findById<T extends Model>(
  model: ModelStatic<T>,
  id: string
): Promise<T | null> {
  const res = await model.findByPk(id, { raw: true });
  return (res as T) || null;
}

/** Create a single record and return the plain object. */
export async function createRecord<T extends Model>(
  model: ModelStatic<T>,
  data: Partial<T>
): Promise<T> {
  const row = await model.create(data as any);
  return row.toJSON() as T;
}

/** Update matching records and return the first updated row. */
export async function updateRecord<T extends Model>(
  model: ModelStatic<T>,
  where: Record<string, any>,
  data: Partial<T>
): Promise<T> {
  const [count, updatedResult] = await model.update(data as any, {
    where: { ...(where as any) },
    returning: true,
  });

  if (count === 0) {
    throw new NotFoundError(`${model.name} not found`);
  }

  if (count > 1) {
    logger.warn(`Found records ${count} matching ${JSON.stringify(where)}`);
  }

  return updatedResult[0];
}

/** Delete matching records and optionally return the deleted row. */
export async function deleteRecord<T extends Model>(
  model: ModelStatic<T>,
  where: Record<string, any>,
  skipGet = false
): Promise<T | number> {
  if (skipGet) {
    const result = await model.destroy({ where });
    if (!result) throw new NotFoundError(`${model.name} not found`);
    return result;
  }
  const row = await model.findOne({ where });
  if (!row) throw new NotFoundError(`${model.name} not found`);
  await (row as any).destroy();
  return row.toJSON() as any;
}

/** Run a callback within a database transaction. */
export async function runTransaction<T>(cb: (t: Transaction) => Promise<T>) {
  const sequelize = getDBConnection();
  return sequelize.transaction(cb);
}
