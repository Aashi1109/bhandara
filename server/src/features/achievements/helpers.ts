import { RedisCache } from "@/features/cache";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";
import type { IAchievementProgress, IUserAchievement } from "@/definitions/types";

const achievementCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Achievements.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Achievements.ttl,
});

export const getUserAchievementsCache = (userId: string) =>
  achievementCache.getItem<IUserAchievement[]>(`${userId}:unlocked`);

export const setUserAchievementsCache = (userId: string, data: IUserAchievement[]) =>
  achievementCache.setItem(`${userId}:unlocked`, data);

export const deleteUserAchievementsCache = (userId: string) =>
  achievementCache.invalidateCache(`${userId}:*`);

export const getUserAchievementProgressCache = (userId: string) =>
  achievementCache.getItem<IAchievementProgress>(`${userId}:progress`);

export const setUserAchievementProgressCache = (
  userId: string,
  data: IAchievementProgress
) => achievementCache.setItem(`${userId}:progress`, data);
