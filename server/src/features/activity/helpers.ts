import { RedisCache } from '@/features/cache';
import { CACHE_NAMESPACE_CONFIG } from '@/constants';
import type { IActivity } from '@/definitions/types';

const activityCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Activity.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Activity.ttl,
});

export const deleteUserActivityCache = (userId: string) => activityCache.invalidateCache(`${userId}:activity:*`);

export const deleteUserUpdatesCache = (userId: string) => activityCache.invalidateCache(`${userId}:updates:*`);

export const getActivityCache = (id: string) => activityCache.getItem<IActivity>(id);

export const setActivityCache = (id: string, data: IActivity) => activityCache.setItem(id, data);

export const deleteActivityCache = (id: string) => activityCache.deleteItem(id);
