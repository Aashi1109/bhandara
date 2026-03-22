import { RedisCache } from '@/features/cache';
import { CACHE_NAMESPACE_CONFIG, REDIS_CONNECTION_NAMES } from '@/constants';
import type { IAchievementProgress } from '@/definitions/types';

const achievementCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Activity,
  namespace: CACHE_NAMESPACE_CONFIG.Achievements.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Achievements.ttl,
});

export const deleteUserAchievementsCache = (userId: string) => achievementCache.invalidateCache(`${userId}:*`);

export const getUserAchievementProgressCache = (userId: string) =>
  achievementCache.getItem<IAchievementProgress>(`${userId}:progress`);

export const setUserAchievementProgressCache = (userId: string, data: IAchievementProgress) =>
  achievementCache.setItem(`${userId}:progress`, data);
