import type { Sequelize } from 'sequelize';
import { assertSeedWorkloadWithinGuard, buildSeedStats, logSeedProgress, resolveRange } from './utils';
import { createAuthUsersForCount, deleteAuthUsers } from './auth';
import { runSeedWorkers } from './parallel';
import type { SeedOptions } from './types';
import { ensureSeedTagIds } from './tags';
import { findReusableSeedUsers, insertCreatedUsers } from './users';

export async function seedFreshDatabase(sequelize: Sequelize, options: SeedOptions) {
  assertSeedWorkloadWithinGuard(options);

  logSeedProgress('Authenticating database connection');
  await sequelize.authenticate();
  logSeedProgress('Database connection authenticated');

  const requestedUserCount = resolveRange(options.users);
  logSeedProgress(`Resolved target user count: ${requestedUserCount}`);

  const reusableUsers = await findReusableSeedUsers(requestedUserCount, options);
  const missingUserCount = Math.max(0, requestedUserCount - reusableUsers.length);
  const authUserIds: string[] = [];

  logSeedProgress(
    `User resolution complete: reused=${reusableUsers.length}, toCreate=${missingUserCount}, reuseMode=${options.reuseExistingUsers ? 'enabled' : 'disabled'}`,
  );

  const userTransaction = await sequelize.transaction();
  let createdUsers = [];

  try {
    if (missingUserCount > 0) {
      logSeedProgress(`Creating ${missingUserCount} new auth users`);
      const { createdUsers: createdAuthUsers } = await createAuthUsersForCount(options, missingUserCount);
      authUserIds.push(...createdAuthUsers.map((user) => user.authUserId));

      createdUsers = await insertCreatedUsers(userTransaction, createdAuthUsers, 'coordinator-created users');
      logSeedProgress(`Inserted ${createdUsers.length} newly created app users`);
    }

    await userTransaction.commit();
  } catch (error) {
    await userTransaction.rollback();
    await deleteAuthUsers(authUserIds);
    throw error;
  }

  const finalUsers = [...reusableUsers, ...createdUsers];
  logSeedProgress(`Dispatching content seeding for ${finalUsers.length} users`);
  const tagIds = await ensureSeedTagIds(sequelize);
  logSeedProgress(`Prepared ${tagIds.length} shared tag ids for worker seeding`);

  let workerResults;
  try {
    workerResults = await runSeedWorkers({
      options,
      allUsers: finalUsers,
      tagIds,
    });
  } catch (error) {
    await deleteAuthUsers(authUserIds);
    throw error;
  }

  const stats = buildSeedStats();
  stats.usersCreated = createdUsers.length;

  let engagementRowsCreated = 0;
  let ratingRowsCreated = 0;

  for (const result of workerResults) {
    stats.eventsCreated += result.stats.eventsCreated;
    stats.threadsCreated += result.stats.threadsCreated;
    stats.messagesCreated += result.stats.messagesCreated;
    stats.reactionsCreated += result.stats.reactionsCreated;
    stats.savesCreated += result.stats.savesCreated;
    stats.achievementsCreated += result.stats.achievementsCreated;
    stats.activitiesCreated += result.stats.activitiesCreated;
    engagementRowsCreated += result.engagementRowsCreated;
    ratingRowsCreated += result.ratingRowsCreated;
  }

  console.log(`Reused ${reusableUsers.length} existing seed users.`);
  console.log(`Created ${createdUsers.length} new users.`);
  console.log(`Created ${stats.eventsCreated} events.`);
  console.log(`Created ${stats.threadsCreated} threads.`);
  console.log(`Created ${stats.messagesCreated} messages.`);
  console.log(`Created ${stats.reactionsCreated} reactions.`);
  console.log(`Created ${stats.savesCreated} saves.`);
  console.log(`Created ${engagementRowsCreated} engagement rows and ${ratingRowsCreated} ratings.`);
  console.log(`Created ${stats.achievementsCreated} achievements.`);
  console.log(`Created ${stats.activitiesCreated} activities.`);
}
