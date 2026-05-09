import { faker } from '@faker-js/faker';
import { type Sequelize } from 'sequelize';
import { getUUIDv7 } from '@/common/helpers';
import {
  EAccessLevel,
  EAddressEntityType,
  EEventParticipantStatus,
  EEventStatus,
  EEventType,
} from '@/common/definitions/enums';
import { EActivityEntityType, EActivityType, EActivityVisibility } from '@/features/activity/constants';
import { Activity } from '@/features/activity/model';
import { Address } from '@/features/addresses/model';
import { EntityEngagement, EntityRating } from '@/features/engagement/model';
import { Event } from '@/features/events/model';
import { Message } from '@/features/messages/model';
import { Reaction } from '@/features/reactions/model';
import { SavedEntity } from '@/features/saves/model';
import { Thread } from '@/features/threads/model';
import { persistAchievementDataForUsers } from './achievements';
import { queueEngagementForContent, queueReactionsForContent, queueSavesForContent } from './engagement';
import type { SeedCoordinatorUser, SeedOptions, UserMetrics } from './types';
import {
  buildEventLocation,
  buildTimings,
  bulkCreateInChunks,
  deriveHierarchicalRange,
  distributeTotalAcrossKeys,
  formatSeedStep,
  flushPendingRows,
  getOrCreateMetrics,
  isTransientDatabaseError,
  logSeedProgress,
  resolveHierarchicalSparseRangeForKey,
  resolveRangeForKey,
} from './utils';
import { DB_BULK_INSERT_CHUNK_SIZE, MESSAGES_EMPTY_PROBABILITY, THREADS_EMPTY_PROBABILITY } from './constants';

export async function seedContentForUsers({
  sequelize,
  assignedUsers,
  allUsers,
  tagIds,
  options,
  shardLabel,
}: {
  sequelize: Sequelize;
  assignedUsers: SeedCoordinatorUser[];
  allUsers: SeedCoordinatorUser[];
  tagIds: string[];
  options: SeedOptions;
  shardLabel: string;
}) {
  const eventRange = deriveHierarchicalRange(options.eventsPerUser, 'event');
  const threadRange = deriveHierarchicalRange(options.threadsPerEvent, 'thread');
  const messageRange = deriveHierarchicalRange(options.messagesPerThread, 'message');
  const step = (phase: string, detail?: string) => formatSeedStep(shardLabel, phase, detail);
  const allUserIds = allUsers.map((user) => user.id);
  const plannedEventCounts = new Map(
    allUsers.map((user) => [
      user.id,
      options.totalEvents !== undefined ? 0 : resolveRangeForKey(eventRange, `${user.id}:events`),
    ]),
  );

  if (options.totalEvents !== undefined) {
    const eventBudgets = distributeTotalAcrossKeys(options.totalEvents, allUserIds, {
      zeroProbability: allUsers.length > 1 ? 0.05 : 0,
      randomnessFactor: 0,
    });
    allUsers.forEach((user, index) => {
      plannedEventCounts.set(user.id, eventBudgets[index] || 0);
    });
  }

  const plannedThreadTotals = new Map<string, number>();
  if (options.totalThreads !== undefined) {
    const threadBudgets = distributeTotalAcrossKeys(options.totalThreads, allUserIds, {
      zeroProbability: THREADS_EMPTY_PROBABILITY,
      baseWeights: allUsers.map((user) => plannedEventCounts.get(user.id) || 0),
      randomnessFactor: 0,
    });
    allUsers.forEach((user, index) => {
      plannedThreadTotals.set(user.id, threadBudgets[index] || 0);
    });
  } else {
    allUsers.forEach((user) => {
      const eventCount = plannedEventCounts.get(user.id) || 0;
      const threadTotal = Array.from({ length: eventCount }, (_, eventIndex) =>
        resolveHierarchicalSparseRangeForKey(
          threadRange,
          THREADS_EMPTY_PROBABILITY,
          'thread',
          `${user.id}:event-slot:${eventIndex}:threads`,
        ),
      ).reduce((sum, count) => sum + count, 0);
      plannedThreadTotals.set(user.id, threadTotal);
    });
  }

  const plannedMessageTotals = new Map<string, number>();
  if (options.totalMessages !== undefined) {
    const messageBudgets = distributeTotalAcrossKeys(options.totalMessages, allUserIds, {
      zeroProbability: MESSAGES_EMPTY_PROBABILITY,
      baseWeights: allUsers.map((user) => plannedThreadTotals.get(user.id) || 0),
      randomnessFactor: 0,
    });
    allUsers.forEach((user, index) => {
      plannedMessageTotals.set(user.id, messageBudgets[index] || 0);
    });
  }

  const stats = {
    eventsCreated: 0,
    threadsCreated: 0,
    messagesCreated: 0,
    reactionsCreated: 0,
    savesCreated: 0,
    achievementsCreated: 0,
    activitiesCreated: 0,
  };
  let engagementRowsCreated = 0;
  let ratingRowsCreated = 0;

  if (assignedUsers.length === 0) {
    logSeedProgress(step('shard', 'skip assignedUsers=0'));
    return {
      stats,
      engagementRowsCreated,
      ratingRowsCreated,
    };
  }

  logSeedProgress(
    step(
      'shard',
      `start assignedUsers=${assignedUsers.length} tagIds=${tagIds.length} eventRange=${eventRange.min}:${eventRange.max} threadRange=${threadRange.min}:${threadRange.max} messageRange=${messageRange.min}:${messageRange.max} totalEvents=${options.totalEvents ?? 'off'} totalThreads=${options.totalThreads ?? 'off'} totalMessages=${options.totalMessages ?? 'off'}`,
    ),
  );

  for (const [assignedIndex, user] of assignedUsers.entries()) {
    logSeedProgress(step('user', `start index=${assignedIndex + 1}/${assignedUsers.length} email=${user.email}`));
    let currentChunkSize = DB_BULK_INSERT_CHUNK_SIZE;
    let attempt = 0;

    while (true) {
      const transaction = await sequelize.transaction();
      const metricsByUserId = new Map<string, UserMetrics>();
      const reactionRows: Array<{ id: string; userId: string; contentId: string; emoji: string }> = [];
      const reactionActivityRows: Array<Record<string, unknown>> = [];
      const saveRows: Array<{
        id: string;
        userId: string;
        entityType: 'event' | 'thread' | 'message';
        entityId: string;
      }> = [];
      const engagementRows: Array<Record<string, unknown>> = [];
      const ratingRows: Array<Record<string, unknown>> = [];
      const userStats = {
        eventsCreated: 0,
        threadsCreated: 0,
        messagesCreated: 0,
        reactionsCreated: 0,
        savesCreated: 0,
        achievementsCreated: 0,
        activitiesCreated: 0,
      };
      let userEngagementRowsCreated = 0;
      let userRatingRowsCreated = 0;

      try {
        const eventsForUser = plannedEventCounts.get(user.id) ?? 0;
        const eventRows = [];
        const eventAddressRows = [];
        const eventActivityRows = [];
        const userEvents: Array<{ id: string; threadsForEvent: number }> = [];
        const userThreadBudget = plannedThreadTotals.get(user.id) ?? 0;
        const userMessageBudget = plannedMessageTotals.get(user.id) ?? 0;

        for (let eventIndex = 0; eventIndex < eventsForUser; eventIndex += 1) {
          const tagSampleSize = Math.min(
            resolveRangeForKey(options.tagsPerEvent, `${user.id}:event-slot:${eventIndex}:tags`),
            tagIds.length,
          );
          const eventTags = faker.helpers.arrayElements(tagIds, tagSampleSize);
          const participantCandidates = allUsers.filter((candidate) => candidate.id !== user.id);
          const participants = faker.helpers
            .arrayElements(
              participantCandidates,
              Math.min(participantCandidates.length, faker.number.int({ min: 0, max: 4 })),
            )
            .map((participant) => ({
              user: participant.id,
              status: faker.helpers.arrayElement([EEventParticipantStatus.Confirmed, EEventParticipantStatus.Pending]),
            }));

          const eventId = getUUIDv7();
          const eventName = `${faker.company.name()} ${faker.helpers.arrayElement(['Zentry', 'Dinner', 'Tasting', 'Meetup'])}`;
          const location = buildEventLocation();
          const threadsForEvent =
            options.totalThreads !== undefined
              ? 0
              : resolveHierarchicalSparseRangeForKey(
                  threadRange,
                  THREADS_EMPTY_PROBABILITY,
                  'thread',
                  `${user.id}:event-slot:${eventIndex}:threads`,
                );

          eventRows.push({
            id: eventId,
            name: eventName,
            description: faker.lorem.paragraph(),
            participants,
            verifiers: [],
            type: faker.helpers.arrayElement([EEventType.Organized, EEventType.Custom]),
            createdBy: user.id,
            isDraft: faker.helpers.arrayElement([false, true]),
            cancelledAt: null,
            capacity: faker.number.int({ min: 50, max: 200 }),
            tags: eventTags,
            media: [],
            ...buildTimings(),
          });
          eventAddressRows.push({
            id: getUUIDv7(),
            entityType: EAddressEntityType.Event,
            entityId: eventId,
            address: location.address,
            latitude: location.latitude,
            longitude: location.longitude,
            metadata: {
              venue: location.venue,
              coordinates: location.coordinates,
            },
          });
          eventActivityRows.push({
            id: getUUIDv7(),
            actorId: user.id,
            recipientId: null,
            type: EActivityType.EventCreated,
            entityType: EActivityEntityType.Event,
            entityId: eventId,
            payload: { name: eventName },
            visibility: EActivityVisibility.Public,
            readAt: null,
          });
          userEvents.push({ id: eventId, threadsForEvent });

          userStats.savesCreated += queueSavesForContent({
            contentId: eventId,
            entityType: 'event',
            createdUserRows: assignedUsers,
            saveRows,
          });
          const eventEngagement = queueEngagementForContent({
            contentId: eventId,
            entityType: 'event',
            createdUserRows: assignedUsers,
            engagementRows,
            ratingRows,
          });
          userEngagementRowsCreated += eventEngagement.engagementCreated;
          userRatingRowsCreated += eventEngagement.ratingCount;
          queueReactionsForContent({
            contentId: eventId,
            createdUserRows: assignedUsers,
            metricsByUserId,
            reactionRows,
            reactionActivityRows,
          });
          getOrCreateMetrics(metricsByUserId, user.id).eventCreated += 1;

          if (reactionRows.length >= currentChunkSize) {
            await flushPendingRows(Reaction, reactionRows, transaction, step('reactions'), currentChunkSize);
            await flushPendingRows(
              Activity,
              reactionActivityRows,
              transaction,
              step('reaction-activities'),
              currentChunkSize,
            );
          }
          if (saveRows.length >= currentChunkSize) {
            await flushPendingRows(SavedEntity, saveRows, transaction, step('saves'), currentChunkSize);
          }
          if (engagementRows.length >= currentChunkSize) {
            await flushPendingRows(EntityEngagement, engagementRows, transaction, step('engagement'), currentChunkSize);
          }
          if (ratingRows.length >= currentChunkSize) {
            await flushPendingRows(EntityRating, ratingRows, transaction, step('ratings'), currentChunkSize);
          }
        }

        if (options.totalThreads !== undefined && userEvents.length > 0) {
          const eventThreadBudgets = distributeTotalAcrossKeys(
            userThreadBudget,
            userEvents.map((_, index) => `${user.id}:event-slot:${index}:thread-budget`),
            {
              zeroProbability: THREADS_EMPTY_PROBABILITY,
            },
          );
          userEvents.forEach((event, index) => {
            event.threadsForEvent = eventThreadBudgets[index] || 0;
          });
        }

        await bulkCreateInChunks(Event, eventRows, transaction, step('events', `user=${user.email}`), currentChunkSize);
        await bulkCreateInChunks(
          Address,
          eventAddressRows,
          transaction,
          step('event-addresses', `user=${user.email}`),
          currentChunkSize,
        );
        await bulkCreateInChunks(
          Activity,
          eventActivityRows,
          transaction,
          step('event-activities', `user=${user.email}`),
          currentChunkSize,
        );
        userStats.eventsCreated += eventRows.length;

        const totalThreadsForUser = userEvents.reduce((sum, event) => sum + event.threadsForEvent, 0);
        const threadMessageBudgets =
          options.totalMessages !== undefined
            ? distributeTotalAcrossKeys(
                userMessageBudget,
                Array.from(
                  { length: totalThreadsForUser },
                  (_, index) => `${user.id}:thread-slot:${index}:message-budget`,
                ),
                {
                  zeroProbability: MESSAGES_EMPTY_PROBABILITY,
                },
              )
            : [];
        let threadSlotIndex = 0;

        for (const event of userEvents) {
          const threadRows: Array<{
            id: string;
            visibility: EAccessLevel;
            parentId: null;
            eventId: string;
            lockHistory: never[];
            createdBy: string;
          }> = [];
          const threadPlans: Array<{ id: string; messagesForThread: number }> = [];
          for (let threadIndex = 0; threadIndex < event.threadsForEvent; threadIndex += 1) {
            const threadId = getUUIDv7();
            const messagesForThread =
              options.totalMessages !== undefined
                ? threadMessageBudgets[threadSlotIndex] || 0
                : resolveHierarchicalSparseRangeForKey(
                    messageRange,
                    MESSAGES_EMPTY_PROBABILITY,
                    'message',
                    `${user.id}:thread-slot:${threadSlotIndex}:messages`,
                  );
            threadSlotIndex += 1;
            threadRows.push({
              id: threadId,
              visibility: EAccessLevel.Public,
              parentId: null,
              eventId: event.id,
              lockHistory: [],
              createdBy: user.id,
            });
            threadPlans.push({ id: threadId, messagesForThread });

            userStats.savesCreated += queueSavesForContent({
              contentId: threadId,
              entityType: 'thread',
              createdUserRows: assignedUsers,
              saveRows,
            });
            const threadEngagement = queueEngagementForContent({
              contentId: threadId,
              entityType: 'thread',
              createdUserRows: assignedUsers,
              engagementRows,
              ratingRows,
            });
            userEngagementRowsCreated += threadEngagement.engagementCreated;
            userRatingRowsCreated += threadEngagement.ratingCount;
            queueReactionsForContent({
              contentId: threadId,
              createdUserRows: assignedUsers,
              metricsByUserId,
              reactionRows,
              reactionActivityRows,
            });
          }

          if (reactionRows.length >= currentChunkSize) {
            await flushPendingRows(Reaction, reactionRows, transaction, step('reactions'), currentChunkSize);
            await flushPendingRows(
              Activity,
              reactionActivityRows,
              transaction,
              step('reaction-activities'),
              currentChunkSize,
            );
          }
          if (saveRows.length >= currentChunkSize) {
            await flushPendingRows(SavedEntity, saveRows, transaction, step('saves'), currentChunkSize);
          }
          if (engagementRows.length >= currentChunkSize) {
            await flushPendingRows(EntityEngagement, engagementRows, transaction, step('engagement'), currentChunkSize);
          }
          if (ratingRows.length >= currentChunkSize) {
            await flushPendingRows(EntityRating, ratingRows, transaction, step('ratings'), currentChunkSize);
          }

          await bulkCreateInChunks(
            Thread,
            threadRows,
            transaction,
            step('threads', `eventId=${event.id}`),
            currentChunkSize,
          );
          userStats.threadsCreated += threadRows.length;

          const messageRows = [];
          const messageActivityRows = [];

          for (const thread of threadPlans) {
            const rootMessageIds: string[] = [];
            for (let messageIndex = 0; messageIndex < thread.messagesForThread; messageIndex += 1) {
              const shouldReply = rootMessageIds.length > 0 && faker.datatype.boolean({ probability: 0.35 });
              const messageId = getUUIDv7();
              const messageUserId = faker.helpers.arrayElement(assignedUsers).id;
              const parentId = shouldReply ? faker.helpers.arrayElement(rootMessageIds) : null;

              messageRows.push({
                id: messageId,
                userId: messageUserId,
                parentId,
                content: { text: faker.lorem.sentences({ min: 1, max: 2 }) },
                isEdited: false,
                threadId: thread.id,
              });
              messageActivityRows.push({
                id: getUUIDv7(),
                actorId: messageUserId,
                recipientId: null,
                type: EActivityType.MessageCreated,
                entityType: EActivityEntityType.Message,
                entityId: messageId,
                payload: { threadId: thread.id, messageId },
                visibility: EActivityVisibility.Public,
                readAt: null,
              });

              if (!shouldReply) {
                rootMessageIds.push(messageId);
              }

              userStats.savesCreated += queueSavesForContent({
                contentId: messageId,
                entityType: 'message',
                createdUserRows: assignedUsers,
                saveRows,
              });
              const messageEngagement = queueEngagementForContent({
                contentId: messageId,
                entityType: 'message',
                createdUserRows: assignedUsers,
                engagementRows,
                ratingRows,
              });
              userEngagementRowsCreated += messageEngagement.engagementCreated;
              userRatingRowsCreated += messageEngagement.ratingCount;
              queueReactionsForContent({
                contentId: messageId,
                createdUserRows: assignedUsers,
                metricsByUserId,
                reactionRows,
                reactionActivityRows,
              });
              getOrCreateMetrics(metricsByUserId, messageUserId).messageCreated += 1;
              userStats.messagesCreated += 1;

              if (messageRows.length >= currentChunkSize) {
                await flushPendingRows(Message, messageRows, transaction, step('messages'), currentChunkSize);
                await flushPendingRows(
                  Activity,
                  messageActivityRows,
                  transaction,
                  step('message-activities'),
                  currentChunkSize,
                );
              }
              if (reactionRows.length >= currentChunkSize) {
                await flushPendingRows(Reaction, reactionRows, transaction, step('reactions'), currentChunkSize);
                await flushPendingRows(
                  Activity,
                  reactionActivityRows,
                  transaction,
                  step('reaction-activities'),
                  currentChunkSize,
                );
              }
              if (saveRows.length >= currentChunkSize) {
                await flushPendingRows(SavedEntity, saveRows, transaction, step('saves'), currentChunkSize);
              }
              if (engagementRows.length >= currentChunkSize) {
                await flushPendingRows(
                  EntityEngagement,
                  engagementRows,
                  transaction,
                  step('engagement'),
                  currentChunkSize,
                );
              }
              if (ratingRows.length >= currentChunkSize) {
                await flushPendingRows(EntityRating, ratingRows, transaction, step('ratings'), currentChunkSize);
              }
            }
          }

          await flushPendingRows(Message, messageRows, transaction, step('messages'), currentChunkSize);
          await flushPendingRows(
            Activity,
            messageActivityRows,
            transaction,
            step('message-activities'),
            currentChunkSize,
          );
        }

        await flushPendingRows(Reaction, reactionRows, transaction, step('reactions'), currentChunkSize);
        await flushPendingRows(
          Activity,
          reactionActivityRows,
          transaction,
          step('reaction-activities'),
          currentChunkSize,
        );
        await flushPendingRows(SavedEntity, saveRows, transaction, step('saves'), currentChunkSize);
        await flushPendingRows(EntityEngagement, engagementRows, transaction, step('engagement'), currentChunkSize);
        await flushPendingRows(EntityRating, ratingRows, transaction, step('ratings'), currentChunkSize);

        userStats.reactionsCreated = Array.from(metricsByUserId.values()).reduce(
          (total, metrics) => total + metrics.reactionCreated,
          0,
        );

        const { createdAchievementRows, progressCount } = await persistAchievementDataForUsers(
          [user],
          metricsByUserId,
          transaction,
        );
        if (progressCount > 0) {
          logSeedProgress(step('achievements', `progress-updated users=${progressCount}`));
        }

        if (createdAchievementRows.length > 0) {
          const achievementActivityRows = createdAchievementRows.map((achievement) => ({
            id: getUUIDv7(),
            actorId: String(achievement.userId),
            recipientId: String(achievement.userId),
            type: EActivityType.AchievementUnlocked,
            entityType: EActivityEntityType.Achievement,
            entityId: String(achievement.id),
            payload: {
              key: achievement.key,
              title: achievement.title,
              description: achievement.description,
              icon: achievement.icon,
            },
            visibility: EActivityVisibility.Private,
            readAt: null,
          }));

          await bulkCreateInChunks(
            Activity,
            achievementActivityRows,
            transaction,
            step('achievement-activities'),
            currentChunkSize,
          );
        }

        userStats.achievementsCreated = createdAchievementRows.length;
        userStats.activitiesCreated =
          userStats.eventsCreated +
          userStats.messagesCreated +
          userStats.reactionsCreated +
          userStats.achievementsCreated;

        await transaction.commit();

        stats.eventsCreated += userStats.eventsCreated;
        stats.threadsCreated += userStats.threadsCreated;
        stats.messagesCreated += userStats.messagesCreated;
        stats.reactionsCreated += userStats.reactionsCreated;
        stats.savesCreated += userStats.savesCreated;
        stats.achievementsCreated += userStats.achievementsCreated;
        stats.activitiesCreated += userStats.activitiesCreated;
        engagementRowsCreated += userEngagementRowsCreated;
        ratingRowsCreated += userRatingRowsCreated;

        logSeedProgress(
          step(
            'user',
            `complete email=${user.email} events=${userStats.eventsCreated} threads=${userStats.threadsCreated} messages=${userStats.messagesCreated} reactions=${userStats.reactionsCreated} saves=${userStats.savesCreated} achievements=${userStats.achievementsCreated} chunkSize=${currentChunkSize}`,
          ),
        );
        break;
      } catch (error) {
        await transaction.rollback();

        if (!isTransientDatabaseError(error) || currentChunkSize <= 1) {
          throw error;
        }

        attempt += 1;
        const nextChunkSize = Math.max(1, Math.floor(currentChunkSize / 2));
        logSeedProgress(
          step(
            'user',
            `retry email=${user.email} attempt=${attempt} reason=${error instanceof Error ? error.message : String(error)} chunkSize=${currentChunkSize} retryChunkSize=${nextChunkSize}`,
          ),
        );
        currentChunkSize = nextChunkSize;
        await new Promise((resolve) => setTimeout(resolve, Math.min(1000 * attempt, 5000)));
      }
    }
  }

  logSeedProgress(
    step(
      'shard',
      `complete events=${stats.eventsCreated} threads=${stats.threadsCreated} messages=${stats.messagesCreated} reactions=${stats.reactionsCreated} saves=${stats.savesCreated} achievements=${stats.achievementsCreated}`,
    ),
  );

  return {
    stats,
    engagementRowsCreated,
    ratingRowsCreated,
  };
}
