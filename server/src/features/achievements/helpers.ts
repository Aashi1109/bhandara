import { RedisCache } from '@/features/cache';
import { CACHE_NAMESPACE_CONFIG, REDIS_CONNECTION_NAMES } from '@/common/constants';
import type { IAchievementProgress } from '@/common';
import { cacheKeys } from '@/features/cache/keys';

const achievementCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Activity,
  namespace: CACHE_NAMESPACE_CONFIG.Achievements.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Achievements.ttl,
});

export const deleteUserAchievementsCache = (userId: string) =>
  achievementCache.invalidateCache(cacheKeys.achievementPattern(userId));

export const getUserAchievementProgressCache = (userId: string) =>
  achievementCache.getItem<IAchievementProgress>(cacheKeys.achievementProgress(userId));

export const setUserAchievementProgressCache = (userId: string, data: IAchievementProgress) =>
  achievementCache.setItem(cacheKeys.achievementProgress(userId), data);
