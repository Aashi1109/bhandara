import { isDeepStrictEqual } from 'node:util';

/** Stringify JSON without additional options. */
export const jnstringify = (payload: any) => JSON.stringify(payload);
/** Parse a JSON string returning the typed value. */
export const jnparse = (payload: any) => JSON.parse(payload);

export const safeJsonParse = (payload: unknown) => {
  try {
    return jnparse(payload);
  } catch {
    return payload;
  }
};

/**
 * Return a new object containing only the specified keys.
 */
export const pick = <T extends Record<string, any>, K extends keyof T>(obj: T, keys: K[]) => {
  return keys.reduce(
    (acc, key) => {
      if (obj[key] !== undefined) {
        acc[key] = obj[key];
      }
      return acc;
    },
    {} as Pick<T, K>,
  );
};

/**
 * Return a new object without the specified keys.
 */
export const omit = <T extends Record<string, any>, K extends keyof T>(obj: T, keys: K[]) => {
  const newObj = { ...obj };
  keys.forEach((key) => {
    delete newObj[key];
  });
  return newObj;
};

/** Check if a value is considered empty. */
export const isEmpty = (value: any) => {
  if (value === null || value === undefined) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === 'object') return Object.keys(value).length === 0;
  return false;
};

/** Deep merge multiple objects. */
export const merge = (...objects: any[]) => {
  const result: any = {};

  objects.forEach((obj) => {
    if (obj && typeof obj === 'object') {
      Object.keys(obj).forEach((key) => {
        if (obj[key] && typeof obj[key] === 'object' && !Array.isArray(obj[key])) {
          result[key] = merge(result[key] || {}, obj[key]);
        } else {
          result[key] = obj[key];
        }
      });
    }
  });

  return result;
};

/** Remove empty values from a query object. */
export const cleanQueryObject = (query: Record<string, any>) => {
  const cleanedQuery: any = {};
  Object.keys(query).forEach((key) => {
    if (query[key] !== undefined && query[key] !== '') {
      cleanedQuery[key] = query[key];
    }
  });
  return cleanedQuery;
};

const normalizeComparableValue = (value: any): any => {
  if (value === null || value === undefined) return value;

  if (typeof value?.toJSON === 'function') {
    return normalizeComparableValue(value.toJSON());
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (Array.isArray(value)) {
    return value.map((item) => normalizeComparableValue(item));
  }

  if (typeof value === 'object') {
    return Object.entries(value).reduce<Record<string, any>>((acc, [key, currentValue]) => {
      if (key === 'updatedAt' || key === 'isEdited') {
        return acc;
      }

      acc[key] = normalizeComparableValue(currentValue);
      return acc;
    }, {});
  }

  return value;
};

/**
 * Compare two payloads while ignoring automatic timestamp churn such as updatedAt.
 */
export const hasMeaningfulChange = (previousValue: any, nextValue: any) => {
  return !isDeepStrictEqual(
    normalizeComparableValue(previousValue),
    normalizeComparableValue(nextValue),
  );
};
