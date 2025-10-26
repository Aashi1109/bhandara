import { FindOptions, Model, ModelStatic, Op } from "sequelize";
import { IPaginationParams } from "@/definitions/types";

export interface PaginatedResult<T> {
  items: T[];
  pagination: IPaginationParams;
}

/**
 * Retrieve records with pagination, supporting both cursor and offset modes.
 * Now accepts full Sequelize FindOptions for maximum flexibility.
 */
export async function findAllWithPagination<T extends Model>(
  model: ModelStatic<T>,
  findOptions: FindOptions = {},
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

  // Start with the provided findOptions and merge pagination logic
  const options: FindOptions = {
    raw: true,
    ...findOptions, // Spread the provided options first
    order: findOptions.order || [
      [_pagination.sortBy, _pagination.sortOrder.toUpperCase()],
    ],
    limit: limit,
  };

  // Select specific fields
  if (select) {
    options.attributes = select.split(",").map((s) => s.trim());
  }

  // Cursor-based pagination
  if (isCursorMode) {
    // Merge cursor condition with existing where clause
    const cursorCondition = {
      [_pagination.sortBy]: {
        [_pagination.sortOrder === "asc" ? Op.gt : Op.lt]: _pagination.next,
      },
    };

    if (findOptions.where) {
      options.where = {
        [Op.and]: [findOptions.where, cursorCondition],
      };
    } else {
      options.where = cursorCondition;
    }
  } else {
    // Offset-based pagination
    options.offset = (_pagination.page - 1) * _pagination.limit;
  }

  // Allow user-defined modification
  if (modifyOptions) {
    Object.assign(options, modifyOptions(options));
  }

  const { rows, count } = await model.findAndCountAll(options);

  const paginationResult = {
    limit,
    total: count,
  } as IPaginationParams;

  if (isCursorMode) {
    // For cursor pagination, check if we got exactly the limit (indicating more results)
    const hasNext = rows.length === _pagination.limit;
    paginationResult.next = hasNext
      ? rows[rows.length - 1][_pagination.sortBy]
      : null;
  } else {
    // For offset pagination, calculate hasNext based on total count and current page
    const totalPages = Math.ceil(count / _pagination.limit);
    const hasNext = _pagination.page < totalPages;

    paginationResult.page = _pagination.page;
    paginationResult.hasNext = hasNext;
    paginationResult.next = hasNext
      ? rows[rows.length - 1][_pagination.sortBy]
      : null;
  }

  const items = rows as T[];

  return { items, pagination: paginationResult };
}
