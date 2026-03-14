import { RedisCache } from "@/features/cache";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";
import type { IActivity } from "@/definitions/types";

const activityCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Activity.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Activity.ttl,
});

const userActivityCacheKey = (userId: string, page: number, limit: number) =>
  `${userId}:activity:page:${page}:limit:${limit}`;

const userUpdatesCacheKey = (
  userId: string,
  page: number,
  limit: number,
  unreadOnly: boolean
) => `${userId}:updates:page:${page}:limit:${limit}:unread:${unreadOnly}`;

export const getUserActivityCache = (
  userId: string,
  page: number,
  limit: number
) => activityCache.getItem(userActivityCacheKey(userId, page, limit));

export const setUserActivityCache = (
  userId: string,
  page: number,
  limit: number,
  data: any
) => activityCache.setItem(userActivityCacheKey(userId, page, limit), data);

export const deleteUserActivityCache = (userId: string) =>
  activityCache.invalidateCache(`${userId}:activity:*`);

export const getUserUpdatesCache = (
  userId: string,
  page: number,
  limit: number,
  unreadOnly: boolean
) =>
  activityCache.getItem(userUpdatesCacheKey(userId, page, limit, unreadOnly));

export const setUserUpdatesCache = (
  userId: string,
  page: number,
  limit: number,
  unreadOnly: boolean,
  data: any
) =>
  activityCache.setItem(
    userUpdatesCacheKey(userId, page, limit, unreadOnly),
    data
  );

export const deleteUserUpdatesCache = (userId: string) =>
  activityCache.invalidateCache(`${userId}:updates:*`);

export const getActivityCache = (id: string) => activityCache.getItem<IActivity>(id);

export const setActivityCache = (id: string, data: IActivity) =>
  activityCache.setItem(id, data);

export const deleteActivityCache = (id: string) => activityCache.deleteItem(id);
