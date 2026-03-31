import { faker } from '@faker-js/faker';
import { Op, type Transaction } from 'sequelize';
import { getUUIDv7 } from '@/helpers';
import { ACHIEVEMENT_DEFINITIONS } from '@/features/achievements/constants';
import { AchievementProgress, UserAchievement } from '@/features/achievements/model';
import type { SeedCoordinatorUser, SeededUserRow, UserMetrics } from './types';
import { getOrCreateMetrics } from './utils';

export function prepareAchievementData(createdUserRows: SeededUserRow[], metricsByUserId: Map<string, UserMetrics>) {
  const achievementRows: Array<Record<string, unknown>> = [];
  const achievementProgressRows = createdUserRows.map((user) => {
    const metrics = getOrCreateMetrics(metricsByUserId, user.id);
    return {
      id: getUUIDv7(),
      userId: user.id,
      metrics: {
        'event.created': metrics.eventCreated,
        'message.created': metrics.messageCreated,
        'reaction.created': metrics.reactionCreated,
        streak: {
          current: metrics.streakCurrent,
          longest: Math.max(metrics.streakLongest, metrics.streakCurrent),
          lastActiveDate: new Date().toISOString().slice(0, 10),
        },
      },
    };
  });

  for (const user of createdUserRows) {
    const metrics = getOrCreateMetrics(metricsByUserId, user.id);
    for (const definition of ACHIEVEMENT_DEFINITIONS) {
      const value =
        definition.type === 'streak'
          ? metrics.streakCurrent
          : definition.metric === 'event.created'
            ? metrics.eventCreated
            : definition.metric === 'message.created'
              ? metrics.messageCreated
              : metrics.reactionCreated;

      if (value < definition.threshold) continue;

      achievementRows.push({
        id: getUUIDv7(),
        userId: user.id,
        key: definition.key,
        title: definition.title,
        description: definition.description,
        icon: definition.icon || null,
        metadata: {
          threshold: definition.threshold,
          metric: definition.metric,
          type: definition.type,
          value,
        },
        unlockedAt: faker.date.recent({ days: 14 }),
      });
    }
  }

  return { achievementRows, achievementProgressRows };
}

export async function persistAchievementDataForUsers(
  users: SeedCoordinatorUser[],
  metricsByUserId: Map<string, UserMetrics>,
  transaction: Transaction,
) {
  if (users.length === 0) {
    return { createdAchievementRows: [], progressCount: 0 };
  }

  const userIds = users.map((user) => user.id);
  const existingProgressRows = (await AchievementProgress.findAll({
    where: { userId: { [Op.in]: userIds } },
    raw: true,
    transaction,
  })) as Array<{ id: string; userId: string; metrics: Record<string, any> }>;

  const progressByUserId = new Map(existingProgressRows.map((row) => [row.userId, row]));
  const nextProgressRows: Array<Record<string, unknown>> = [];
  const today = new Date().toISOString().slice(0, 10);

  for (const user of users) {
    const metrics = getOrCreateMetrics(metricsByUserId, user.id);
    const existing = progressByUserId.get(user.id);
    const existingMetrics = existing?.metrics || {};
    const existingStreak = existingMetrics.streak || {};

    nextProgressRows.push({
      id: existing?.id || getUUIDv7(),
      userId: user.id,
      metrics: {
        'event.created': Number(existingMetrics['event.created'] || 0) + metrics.eventCreated,
        'message.created': Number(existingMetrics['message.created'] || 0) + metrics.messageCreated,
        'reaction.created': Number(existingMetrics['reaction.created'] || 0) + metrics.reactionCreated,
        streak: {
          current: Math.max(Number(existingStreak.current || 0), metrics.streakCurrent),
          longest: Math.max(Number(existingStreak.longest || 0), metrics.streakLongest, metrics.streakCurrent),
          lastActiveDate: existingStreak.lastActiveDate || today,
        },
      },
    });
  }

  const progressInserts = nextProgressRows.filter((row) => !progressByUserId.has(String(row.userId)));
  const progressUpdates = nextProgressRows.filter((row) => progressByUserId.has(String(row.userId)));

  if (progressInserts.length > 0) {
    await AchievementProgress.bulkCreate(progressInserts as any, {
      transaction,
      returning: false,
    });
  }

  for (const row of progressUpdates) {
    await AchievementProgress.update({ metrics: row.metrics } as any, {
      where: { id: row.id as string },
      transaction,
    });
  }

  const existingAchievements = (await UserAchievement.findAll({
    where: { userId: { [Op.in]: userIds } },
    attributes: ['userId', 'key'],
    raw: true,
    transaction,
  })) as Array<{ userId: string; key: string }>;
  const existingAchievementKeys = new Set(existingAchievements.map((row) => `${row.userId}:${row.key}`));

  const createdAchievementRows: Array<Record<string, unknown>> = [];
  for (const row of nextProgressRows) {
    const metrics = row.metrics as Record<string, any>;
    for (const definition of ACHIEVEMENT_DEFINITIONS) {
      const lookupKey = `${row.userId}:${definition.key}`;
      if (existingAchievementKeys.has(lookupKey)) continue;

      const value =
        definition.type === 'streak'
          ? Number(metrics?.streak?.current || 0)
          : Number(metrics?.[definition.metric] || 0);

      if (value < definition.threshold) continue;

      existingAchievementKeys.add(lookupKey);
      createdAchievementRows.push({
        id: getUUIDv7(),
        userId: row.userId,
        key: definition.key,
        title: definition.title,
        description: definition.description,
        icon: definition.icon || null,
        metadata: {
          threshold: definition.threshold,
          metric: definition.metric,
          type: definition.type,
          value,
        },
        unlockedAt: faker.date.recent({ days: 14 }),
      });
    }
  }

  if (createdAchievementRows.length > 0) {
    await UserAchievement.bulkCreate(createdAchievementRows as any, {
      transaction,
      returning: false,
    });
  }

  return {
    createdAchievementRows,
    progressCount: nextProgressRows.length,
  };
}
