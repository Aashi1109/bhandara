import { RedisCache } from '@/src/features/cache';
import { CACHE_NAMESPACE_CONFIG, REDIS_CONNECTION_NAMES } from '@/src/common/constants';
import type { IActivity } from '@/src/common/definitions/types';
import { cacheKeys } from '@/src/features/cache/keys';

const activityCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Activity,
  namespace: CACHE_NAMESPACE_CONFIG.Activity.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Activity.ttl,
});

export const deleteUserActivityCache = (userId: string) =>
  activityCache.invalidateCache(cacheKeys.userActivityPattern(userId));

export const deleteUserUpdatesCache = (userId: string) =>
  activityCache.invalidateCache(cacheKeys.userUpdatesPattern(userId));

export const getActivityCache = (id: string) => activityCache.getItem<IActivity>(cacheKeys.activityItem(id));

export const setActivityCache = (id: string, data: IActivity) =>
  activityCache.setItem(cacheKeys.activityItem(id), data);

export const deleteActivityCache = (id: string) => activityCache.deleteItem(cacheKeys.activityItem(id));
