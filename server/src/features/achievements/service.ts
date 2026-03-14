import type { IAchievementProgress, IUserAchievement } from "@/definitions/types";
import { AchievementProgress, UserAchievement } from "./model";
import {
  ACHIEVEMENT_DEFINITIONS,
  type IAchievementDefinition,
} from "./constants";
import {
  deleteUserAchievementsCache,
  getUserAchievementProgressCache,
  getUserAchievementsCache,
  setUserAchievementProgressCache,
  setUserAchievementsCache,
} from "./helpers";
import { EActivityEntityType, EActivityType, EActivityVisibility } from "@/features/activity/constants";
import ActivityService from "@/features/activity/service";

class AchievementService {
  private readonly activityService: ActivityService;

  constructor() {
    this.activityService = new ActivityService();
  }

  getDefinitions() {
    return ACHIEVEMENT_DEFINITIONS;
  }

  async getUserAchievements(userId: string): Promise<IUserAchievement[]> {
    const cached = await getUserAchievementsCache(userId);
    if (cached) return cached;

    const rows = await UserAchievement.findAll({
      where: { userId },
      order: [["unlockedAt", "DESC"]],
      raw: true,
    });

    const achievements = rows as IUserAchievement[];
    await setUserAchievementsCache(userId, achievements);
    return achievements;
  }

  async getUserProgress(userId: string): Promise<IAchievementProgress> {
    const cached = await getUserAchievementProgressCache(userId);
    if (cached) return cached;

    const row = await this.getOrCreateProgress(userId);
    await setUserAchievementProgressCache(userId, row);
    return row;
  }

  private async getOrCreateProgress(userId: string): Promise<IAchievementProgress> {
    const existing = await AchievementProgress.findOne({
      where: { userId },
      raw: true,
    });

    if (existing) return existing as IAchievementProgress;

    const created = await AchievementProgress.create({
      userId,
      metrics: {},
    });

    return created.toJSON() as IAchievementProgress;
  }

  private buildUpdatedMetrics(
    currentMetrics: Record<string, any>,
    activityType: string,
    occurredAt: Date
  ) {
    const metrics = { ...currentMetrics };

    metrics[activityType] = (metrics[activityType] || 0) + 1;

    const today = occurredAt.toISOString().slice(0, 10);
    const streak = {
      current: Number(metrics?.streak?.current || 0),
      longest: Number(metrics?.streak?.longest || 0),
      lastActiveDate: metrics?.streak?.lastActiveDate || null,
    };

    if (streak.lastActiveDate !== today) {
      const lastDate = streak.lastActiveDate
        ? new Date(`${streak.lastActiveDate}T00:00:00.000Z`)
        : null;
      const yesterday = new Date(`${today}T00:00:00.000Z`);
      yesterday.setUTCDate(yesterday.getUTCDate() - 1);

      if (lastDate && lastDate.toISOString().slice(0, 10) === yesterday.toISOString().slice(0, 10)) {
        streak.current += 1;
      } else {
        streak.current = 1;
      }

      streak.longest = Math.max(streak.longest, streak.current);
      streak.lastActiveDate = today;
    }

    metrics.streak = streak;
    return metrics;
  }

  private async unlockAchievement(
    userId: string,
    definition: IAchievementDefinition
  ): Promise<IUserAchievement | null> {
    const existing = await UserAchievement.findOne({
      where: { userId, key: definition.key },
      raw: true,
    });

    if (existing) return null;

    const created = await UserAchievement.create({
      userId,
      key: definition.key,
      title: definition.title,
      description: definition.description,
      icon: definition.icon || null,
      metadata: {
        threshold: definition.threshold,
        metric: definition.metric,
        type: definition.type,
      },
      unlockedAt: new Date(),
    });

    const achievement = created.toJSON() as IUserAchievement;

    await Promise.all([
      deleteUserAchievementsCache(userId),
      this.activityService.create({
        actorId: userId,
        recipientId: userId,
        type: EActivityType.AchievementUnlocked,
        entityType: EActivityEntityType.Achievement,
        entityId: achievement.id,
        payload: {
          key: achievement.key,
          title: achievement.title,
          description: achievement.description,
          icon: achievement.icon,
        },
        visibility: EActivityVisibility.Private,
        readAt: null,
      }),
    ]);

    return achievement;
  }

  async trackActivity(
    userId: string,
    activityType: string,
    occurredAt: Date = new Date()
  ) {
    const progress = await this.getOrCreateProgress(userId);
    const metrics = this.buildUpdatedMetrics(
      progress.metrics || {},
      activityType,
      occurredAt
    );

    const row = await AchievementProgress.findByPk(progress.id);
    if (!row) return { unlocked: [], progress };

    await row.update({ metrics });

    const updatedProgress = row.toJSON() as IAchievementProgress;
    await setUserAchievementProgressCache(userId, updatedProgress);

    const unlocked = await Promise.all(
      ACHIEVEMENT_DEFINITIONS.map(async (def) => {
        const value =
          def.type === "streak"
            ? Number(metrics?.streak?.current || 0)
            : Number(metrics?.[def.metric] || 0);

        if (value < def.threshold) return null;

        return this.unlockAchievement(userId, def);
      })
    );

    return {
      unlocked: unlocked.filter(Boolean),
      progress: updatedProgress,
    };
  }
}

export default AchievementService;
