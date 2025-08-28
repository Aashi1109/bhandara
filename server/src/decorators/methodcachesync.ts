import { NotFoundError, UnauthorizedError } from "@/exceptions";
import { isEmpty } from "@/utils";

/**
 * @deprecated This decorator is no longer maintained. Use the
 * cache helper methods directly within your services instead of
 * relying on this wrapper.
 */

export type MethodType = "create" | "update" | "delete" | "get";

// Base interface for cache operations
interface CacheOperations<T = any> {
  getCache: (key: string) => Promise<T | T[] | null>;
  setCache: (key: string, value: T | T[]) => Promise<void>;
  deleteCache: (key: string | Record<string, any>) => Promise<void>;
}

// Interface for the class that will use the decorator
export interface CacheableClass<T = any> extends CacheOperations<T> {
  getById: (id: string) => Promise<T | null>;
  _getByIdNoCache: (id: string) => Promise<T | null>;
}

// Options for the decorator
export interface CacheDecoratorOptions<T = any> {
  methodType?: MethodType;
  cacheGetter?: (key: string) => Promise<T | T[] | null>;
  cacheSetter?: (key: string, value: T | T[]) => Promise<"OK">;
  cacheDeleter?: (key: string, existingData: T | T[]) => Promise<any>;
  cacheSetterWithExistingTTL?: (key: string, value: T) => Promise<"OK">;
  customCacheKey?: (...args: any[]) => string;
}

const extractData = <T>(result: any): T | null => {
  if (result && typeof result === "object" && "data" in result) {
    return result.data as T;
  }
  return (result ?? null) as T | null;
};

const extractError = (result: any) => {
  if (result && typeof result === "object" && "error" in result) {
    return result.error;
  }
  return null;
};

const checkAndThrowRLSError = <T>(result: any, existingData: T | null) => {
  const data = extractData<T>(result);
  const error = extractError(result);
  if (!error && !data && !isEmpty(existingData)) {
    throw new UnauthorizedError("Operation not allowed");
  }
};

/**
 * A decorator that adds caching functionality to class methods
 * @template T The type of data being cached
 * @param {CacheDecoratorOptions<T>} [options] Optional configuration for the cache decorator
 * @returns {Function} A method decorator that adds caching behavior
 *
 * @example
 * ```typescript
 * class UserService {
 *   @MethodCacheSync<User>()
 *   async getById(id: string) {
 *     // Method implementation
 *   }
 * }
 * ```
 */
function MethodCacheSync<T = any>(
  options?: CacheDecoratorOptions<T>
): Function {
  return function <M extends (...args: any[]) => Promise<any>>(
    target: Object,
    propertyKey: string,
    descriptor: TypedPropertyDescriptor<M>
  ): TypedPropertyDescriptor<M> {
    const originalMethod = descriptor.value!;
    const methodPrefix = propertyKey.match(/^[a-z]+/)?.[0] || "";
    const methodType = options?.methodType || (methodPrefix as MethodType);

    /**
     * The wrapped method that implements caching logic
     * @this {CacheableClass<T>} The class instance with cache operations
     * @param {...Parameters<M>} args The arguments passed to the original method
     * @returns {Promise<ReturnType<M>>} The result of the method execution
     */
    descriptor.value = async function (
      this: CacheableClass<T>,
      ...args: Parameters<M>
    ): Promise<ReturnType<M>> {
      // Bind the methods to the current instance
      const boundGetCache = (options?.cacheGetter || this.getCache).bind(this);
      const boundSetCache = (options?.cacheSetter || this.setCache).bind(this);
      const boundDeleteCache = (options?.cacheDeleter || this.deleteCache).bind(
        this
      );
      const boundGetById = (this?._getByIdNoCache || this.getById).bind(this);

      const cacheKey = options?.customCacheKey
        ? options.customCacheKey(...args)
        : args[0];

      switch (methodType) {
        case "create": {
          const result = await originalMethod.apply(this, args);
          const data = extractData<T>(result);

          if (data) {
            const getCacheKey = (id: string) =>
              options?.customCacheKey ? options.customCacheKey(id) : id;

            if (Array.isArray(data)) {
              const promises = data.map(async (item: any) => {
                await boundSetCache(getCacheKey(item.id), item);
              });
              await Promise.all(promises);
            } else if (typeof data === "object") {
              await boundSetCache(getCacheKey((data as any).id), data);
            }
          }
          return result as ReturnType<M>;
        }

        case "update": {
          const existingData = await boundGetById(cacheKey);
          if (isEmpty(existingData))
            throw new NotFoundError("Resource not found");

          const result = await originalMethod.apply(this, args);
          checkAndThrowRLSError(result, existingData);

          const cacheSaver =
            options?.cacheSetterWithExistingTTL || boundSetCache;
          const data = extractData<T>(result);

          if (data) {
            if (typeof data === "object") {
              await cacheSaver(cacheKey, { ...existingData, ...data });
            } else {
              await cacheSaver(cacheKey, data);
            }
          }
          return result as ReturnType<M>;
        }

        case "delete": {
          const existingData = await boundGetById(cacheKey);
          if (isEmpty(existingData))
            throw new NotFoundError("Resource not found");

          const result = await originalMethod.apply(this, args);
          checkAndThrowRLSError(result, existingData);

          const data = extractData<T>(result);
          if (data) await boundDeleteCache(cacheKey, existingData as any);

          return result as ReturnType<M>;
        }

        case "get": {
          const cachedData = await boundGetCache(cacheKey);
          if (!isEmpty(cachedData)) return cachedData as ReturnType<M>;

          const result = await originalMethod.apply(this, args);
          checkAndThrowRLSError(result, cachedData as any);

          const data = extractData<T>(result);
          if (!isEmpty(data)) await boundSetCache(cacheKey, data as any);

          return result as ReturnType<M>;
        }

        default:
          return originalMethod.apply(this, args);
      }
    } as M;

    return descriptor;
  };
}

export default MethodCacheSync;
