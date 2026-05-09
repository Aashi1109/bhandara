import { faker } from '@faker-js/faker';
import { getUUIDv7 } from '@/common/helpers';
import { EActivityEntityType, EActivityType, EActivityVisibility } from '@/features/activity/constants';
import { REACTION_EMOJIS } from './constants';
import type { SeededUserRow, UserMetrics } from './types';
import { getEngagementViewCount, getOrCreateMetrics } from './utils';

export function queueSavesForContent({
  contentId,
  entityType,
  createdUserRows,
  saveRows,
}: {
  contentId: string;
  entityType: 'event' | 'thread' | 'message';
  createdUserRows: SeededUserRow[];
  saveRows: Array<{ id: string; userId: string; entityType: 'event' | 'thread' | 'message'; entityId: string }>;
}) {
  const saveCount = faker.number.int({
    min: 0,
    max: Math.min(entityType === 'event' ? 2 : 1, createdUserRows.length),
  });

  if (saveCount === 0) return 0;

  const savingUsers = faker.helpers.arrayElements(createdUserRows, saveCount);
  for (const savingUser of savingUsers) {
    saveRows.push({
      id: getUUIDv7(),
      userId: savingUser.id,
      entityType,
      entityId: contentId,
    });
  }

  return saveCount;
}

export function queueEngagementForContent({
  contentId,
  entityType,
  createdUserRows,
  engagementRows,
  ratingRows,
}: {
  contentId: string;
  entityType: 'event' | 'thread' | 'message';
  createdUserRows: SeededUserRow[];
  engagementRows: Array<Record<string, unknown>>;
  ratingRows: Array<Record<string, unknown>>;
}) {
  const shouldCreateEngagement = faker.datatype.boolean({
    probability: entityType === 'event' ? 0.8 : entityType === 'thread' ? 0.55 : 0.35,
  });

  if (!shouldCreateEngagement) return { engagementCreated: 0, ratingCount: 0 };

  const ratingCount = faker.number.int({
    min: 0,
    max: Math.min(entityType === 'event' ? 3 : 2, createdUserRows.length),
  });
  const ratingUsers = ratingCount > 0 ? faker.helpers.arrayElements(createdUserRows, ratingCount) : [];
  const ratingValues = ratingUsers.map(() => faker.number.int({ min: 1, max: 5 }));
  const histogram = { '1': 0, '2': 0, '3': 0, '4': 0, '5': 0 };

  ratingValues.forEach((value) => {
    histogram[String(value) as keyof typeof histogram] += 1;
  });

  ratingUsers.forEach((ratingUser, index) => {
    ratingRows.push({
      id: getUUIDv7(),
      entityType,
      entityId: contentId,
      userId: ratingUser.id,
      value: ratingValues[index],
      review: faker.datatype.boolean({ probability: 0.3 }) ? faker.lorem.sentence() : null,
    });
  });

  const ratingAverage =
    ratingValues.length > 0
      ? Number((ratingValues.reduce((total, value) => total + value, 0) / ratingValues.length).toFixed(2))
      : 0;

  engagementRows.push({
    id: getUUIDv7(),
    entityType,
    entityId: contentId,
    stats: {
      viewCount: getEngagementViewCount(entityType),
      ratingCount: ratingValues.length,
      ratingAverage,
      ratingHistogram: histogram,
    },
  });

  return { engagementCreated: 1, ratingCount: ratingValues.length };
}

export function queueReactionsForContent({
  contentId,
  createdUserRows,
  metricsByUserId,
  reactionRows,
  reactionActivityRows,
}: {
  contentId: string;
  createdUserRows: SeededUserRow[];
  metricsByUserId: Map<string, UserMetrics>;
  reactionRows: Array<{ id: string; userId: string; contentId: string; emoji: string }>;
  reactionActivityRows: Array<Record<string, unknown>>;
}) {
  const reactionCount = faker.number.int({
    min: 0,
    max: Math.min(2, createdUserRows.length),
  });

  if (reactionCount === 0) return;

  const reactingUsers = faker.helpers.arrayElements(createdUserRows, reactionCount);
  for (const reactingUser of reactingUsers) {
    const reactionId = getUUIDv7();
    const emoji = faker.helpers.arrayElement(REACTION_EMOJIS);

    reactionRows.push({
      id: reactionId,
      userId: reactingUser.id,
      contentId,
      emoji,
    });
    reactionActivityRows.push({
      id: getUUIDv7(),
      actorId: reactingUser.id,
      recipientId: null,
      type: EActivityType.ReactionCreated,
      entityType: EActivityEntityType.Reaction,
      entityId: reactionId,
      payload: {
        emoji,
        contentId,
      },
      visibility: EActivityVisibility.Public,
      readAt: null,
    });

    getOrCreateMetrics(metricsByUserId, reactingUser.id).reactionCreated += 1;
  }
}
