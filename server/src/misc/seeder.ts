/* eslint-disable no-console */
import { faker } from '@faker-js/faker';
import dotenv from 'dotenv';
import type { Transaction } from 'sequelize';

import { disconnect, getDBConnection } from '@/connections/db';
import {
  EAccessLevel,
  EAuthProvider,
  EEventParticipantStatus,
  EEventStatus,
  EEventType,
} from '@/definitions/enums';
import { getUUIDv7 } from '@/helpers';
import AuthService from '@/features/auth/service';
import { AchievementProgress, UserAchievement } from '@/features/achievements/model';
import { ACHIEVEMENT_DEFINITIONS } from '@/features/achievements/constants';
import { Activity } from '@/features/activity/model';
import { EActivityEntityType, EActivityType, EActivityVisibility } from '@/features/activity/constants';
import { Event } from '@/features/events/model';
import { fallbackTagSeeds } from './clusterSeedConfig';
import { Message } from '@/features/messages/model';
import { Reaction } from '@/features/reactions/model';
import { Tag } from '@/features/tags/model';
import { Thread } from '@/features/threads/model';
import { User } from '@/features/users/model';
import {
  buildAddress,
  buildEventLocation,
  buildSeedStats,
  buildTimings,
  formatRange,
  getOrCreateMetrics,
  parseOptions,
  resolveRange,
  type SeedOptions,
  type UserMetrics,
} from './seederUtils';

dotenv.config();

type SeededEventRow = {
  id: string;
  name: string;
  createdBy: string;
};

type SeededThreadRow = {
  id: string;
  createdBy: string;
};

type SeededMessageRow = {
  id: string;
  userId: string;
};

type SeededReactionRow = {
  id: string;
  userId: string;
  contentId: string;
  emoji: string;
};

type SeededAuthUser = {
  authUserId: string;
  email: string;
  password: string;
  name: string;
  gender: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  expiresIn: number;
};

type SeededUserRow = {
  id: string;
  email: string;
  name: string;
};

const REACTION_EMOJIS = ['❤️', '🔥', '👏', '🍲', '😋', '🙌'];

async function ensureTags(transaction: Transaction) {
  await Tag.bulkCreate(fallbackTagSeeds, {
    transaction,
    ignoreDuplicates: true,
  });

  return Tag.findAll({
    attributes: ['id'],
    raw: true,
    transaction,
  });
}

async function createAuthUsers(options: SeedOptions) {
  const authService = new AuthService();
  const createdUsers: SeededAuthUser[] = [];
  const totalUsers = resolveRange(options.users);
  const redirectTo = process.env.SUPABASE_AUTH_REDIRECT_URL || 'http://localhost:3000';

  for (let index = 0; index < totalUsers; index += 1) {
    const firstName = faker.person.firstName();
    const lastName = faker.person.lastName();
    const name = `${firstName} ${lastName}`;
    const emailSlug = `${firstName}.${lastName}`.toLowerCase().replace(/[^a-z0-9]+/g, '.');
    const uniqueSuffix = faker.string.alphanumeric({ length: 4 }).toLowerCase();
    const email = `${options.emailPrefix}.${emailSlug}.${uniqueSuffix}@bhandara.dev`;
    const gender = faker.helpers.arrayElement(['male', 'female', 'non-binary']);

    const signUpData = await authService.signUpNewUser(email, options.password, redirectTo);
    const sessionData = signUpData.session
      ? signUpData
      : await authService.signInWithEmail(email, options.password);

    if (!signUpData.user || !sessionData.session) {
      throw new Error(`Failed to create auth user for ${email}`);
    }

    createdUsers.push({
      authUserId: signUpData.user.id,
      email,
      password: options.password,
      name,
      gender,
      accessToken: sessionData.session.access_token,
      refreshToken: sessionData.session.refresh_token,
      expiresAt: new Date(new Date(0).setUTCSeconds(sessionData.session.expires_at)).toISOString(),
      expiresIn: sessionData.session.expires_in,
    });
  }

  return {
    createdUsers,
  };
}

async function deleteAuthUsers(userIds: string[]) {
  if (userIds.length === 0) return;
  console.warn(
    `Database transaction rolled back, but ${userIds.length} Supabase auth users may still exist because the seeder is using non-admin auth signup.`,
  );
}

async function seedFreshDatabase(options: SeedOptions) {
  const sequelize = getDBConnection();
  await sequelize.authenticate();

  const { createdUsers } = await createAuthUsers(options);
  const authUserIds = createdUsers.map((user) => user.authUserId);
  const transaction = await sequelize.transaction();
  const stats = buildSeedStats();

  try {
    const availableTags = await ensureTags(transaction);
    const tagIds = availableTags.map((tag) => tag.id);
    const createdUserRows: SeededUserRow[] = [];
    const createdEvents: SeededEventRow[] = [];
    const createdThreads: SeededThreadRow[] = [];
    const createdMessages: SeededMessageRow[] = [];
    const metricsByUserId = new Map<string, UserMetrics>();

    for (const authUser of createdUsers) {
      const userRow = await User.create(
        {
          id: getUUIDv7(),
          name: authUser.name,
          email: authUser.email,
          gender: authUser.gender,
          address: buildAddress(),
          isVerified: true,
          profilePic: null,
          username: faker.internet.username().toLowerCase(),
          password: null,
          meta: {
            auth: {
              provider: EAuthProvider.Email,
              supabaseUserId: authUser.authUserId,
              accessToken: authUser.accessToken,
              refreshToken: authUser.refreshToken,
              expiresAt: authUser.expiresAt,
              expiresIn: authUser.expiresIn,
            },
            hasOnboarded: true,
          },
        },
        { transaction },
      );

      createdUserRows.push({
        id: userRow.id,
        email: userRow.email,
        name: userRow.name,
      });
      stats.usersCreated += 1;
    }

    for (const user of createdUserRows) {
      const eventsForUser = resolveRange(options.eventsPerUser);
      for (let eventIndex = 0; eventIndex < eventsForUser; eventIndex += 1) {
        const tagSampleSize = Math.min(resolveRange(options.tagsPerEvent), tagIds.length);
        const eventTags = faker.helpers.arrayElements(tagIds, tagSampleSize);
        const participantCandidates = createdUserRows.filter((candidate) => candidate.id !== user.id);
        const participants = faker.helpers
          .arrayElements(
            participantCandidates,
            Math.min(participantCandidates.length, faker.number.int({ min: 0, max: 4 })),
          )
          .map((participant) => ({
            user: participant.id,
            status: faker.helpers.arrayElement([EEventParticipantStatus.Confirmed, EEventParticipantStatus.Pending]),
          }));

        const event = await Event.create(
          {
            name: `${faker.company.name()} ${faker.helpers.arrayElement(['Bhandara', 'Dinner', 'Tasting', 'Meetup'])}`,
            description: faker.lorem.paragraph(),
            location: buildEventLocation(),
            participants,
            verifiers: [],
            type: faker.helpers.arrayElement([EEventType.Organized, EEventType.Custom]),
            createdBy: user.id,
            status: faker.helpers.arrayElement([EEventStatus.Upcoming, EEventStatus.Draft]),
            capacity: faker.number.int({ min: 50, max: 200 }),
            tags: eventTags,
            media: [],
            timings: buildTimings(),
          },
          { transaction },
        );
        stats.eventsCreated += 1;
        createdEvents.push({
          id: event.id,
          name: event.name,
          createdBy: user.id,
        });
        getOrCreateMetrics(metricsByUserId, user.id).eventCreated += 1;

        const threadsForEvent = resolveRange(options.threadsPerEvent);
        for (let threadIndex = 0; threadIndex < threadsForEvent; threadIndex += 1) {
          const thread = await Thread.create(
            {
              visibility: EAccessLevel.Public,
              parentId: null,
              eventId: event.id,
              lockHistory: [],
              createdBy: user.id,
            },
            { transaction },
          );
          stats.threadsCreated += 1;
          createdThreads.push({
            id: thread.id,
            createdBy: user.id,
          });

          const rootMessageIds: string[] = [];
          const messagesForThread = resolveRange(options.messagesPerThread);
          for (let messageIndex = 0; messageIndex < messagesForThread; messageIndex += 1) {
            const shouldReply = rootMessageIds.length > 0 && faker.datatype.boolean({ probability: 0.35 });
            const message = await Message.create(
              {
                id: getUUIDv7(),
                userId: faker.helpers.arrayElement(createdUserRows).id,
                parentId: shouldReply ? faker.helpers.arrayElement(rootMessageIds) : null,
                content: {
                  text: faker.lorem.sentences({ min: 1, max: 2 }),
                },
                isEdited: false,
                threadId: thread.id,
              },
              { transaction },
            );

            if (!shouldReply) {
              rootMessageIds.push(message.id);
            }
            createdMessages.push({
              id: message.id,
              userId: message.userId,
            });
            getOrCreateMetrics(metricsByUserId, message.userId).messageCreated += 1;
            stats.messagesCreated += 1;
          }
        }
      }
    }

    const contentIds = [
      ...createdEvents.map((event) => event.id),
      ...createdThreads.map((thread) => thread.id),
      ...createdMessages.map((message) => message.id),
    ];

    const reactionRows: SeededReactionRow[] = [];
    if (contentIds.length > 0 && createdUserRows.length > 0) {
      for (const user of createdUserRows) {
        const reactionCount = faker.number.int({
          min: 0,
          max: Math.min(contentIds.length, Math.max(3, Math.ceil(contentIds.length * 0.15))),
        });

        if (reactionCount === 0) continue;

        const chosenContentIds = faker.helpers.arrayElements(contentIds, reactionCount);
        for (const contentId of chosenContentIds) {
          const reaction = await Reaction.create(
            {
              id: getUUIDv7(),
              userId: user.id,
              contentId,
              emoji: faker.helpers.arrayElement(REACTION_EMOJIS),
            },
            { transaction },
          );

          reactionRows.push({
            id: reaction.id,
            userId: reaction.userId,
            contentId: reaction.contentId,
            emoji: reaction.emoji,
          });
          getOrCreateMetrics(metricsByUserId, user.id).reactionCreated += 1;
          stats.reactionsCreated += 1;
        }
      }
    }

    const achievementRows = [];
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

    if (achievementProgressRows.length > 0) {
      await AchievementProgress.bulkCreate(achievementProgressRows, { transaction });
    }

    if (achievementRows.length > 0) {
      await UserAchievement.bulkCreate(achievementRows, { transaction });
      stats.achievementsCreated = achievementRows.length;
    }

    const activityRows = [
      ...createdEvents.map((event) => ({
        id: getUUIDv7(),
        actorId: event.createdBy,
        recipientId: null,
        type: EActivityType.EventCreated,
        entityType: EActivityEntityType.Event,
        entityId: event.id,
        payload: { name: event.name },
        visibility: EActivityVisibility.Public,
        readAt: null,
      })),
      ...createdMessages.map((message) => ({
        id: getUUIDv7(),
        actorId: message.userId,
        recipientId: null,
        type: EActivityType.MessageCreated,
        entityType: EActivityEntityType.Message,
        entityId: message.id,
        payload: {},
        visibility: EActivityVisibility.Public,
        readAt: null,
      })),
      ...reactionRows.map((reaction) => ({
        id: getUUIDv7(),
        actorId: reaction.userId,
        recipientId: null,
        type: EActivityType.ReactionCreated,
        entityType: EActivityEntityType.Reaction,
        entityId: reaction.id,
        payload: {
          emoji: reaction.emoji,
          contentId: reaction.contentId,
        },
        visibility: EActivityVisibility.Public,
        readAt: null,
      })),
      ...achievementRows.map((achievement) => ({
        id: getUUIDv7(),
        actorId: achievement.userId,
        recipientId: achievement.userId,
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
      })),
    ];

    if (activityRows.length > 0) {
      await Activity.bulkCreate(activityRows, { transaction });
      stats.activitiesCreated = activityRows.length;
    }

    await transaction.commit();

    console.log(
      `Created ${stats.usersCreated} users via Supabase email/password auth (requested range ${formatRange(options.users)}).`,
    );
    console.log(`Created ${stats.eventsCreated} events from per-user range ${formatRange(options.eventsPerUser)}.`);
    console.log(
      `Created ${stats.threadsCreated} threads from per-event range ${formatRange(options.threadsPerEvent)}.`,
    );
    console.log(
      `Created ${stats.messagesCreated} messages from per-thread range ${formatRange(options.messagesPerThread)}.`,
    );
    console.log(`Created ${stats.reactionsCreated} reactions.`);
    console.log(`Created ${stats.achievementsCreated} unlocked achievements.`);
    console.log(`Created ${stats.activitiesCreated} activity records.`);
    console.log('Seeded login credentials:');
    createdUserRows.forEach((user) => {
      console.log(`- ${user.email} / ${options.password}`);
    });
  } catch (error) {
    await transaction.rollback();
    await deleteAuthUsers(authUserIds);
    throw error;
  } finally {
    await disconnect();
  }
}

async function main() {
  const options = parseOptions(process.argv.slice(2));
  await seedFreshDatabase(options);
}

main().catch((error) => {
  console.error('Fresh database seed failed:', error);
  disconnect().finally(() => process.exit(1));
});
