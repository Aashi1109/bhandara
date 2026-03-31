import dotenv from 'dotenv';
import { disconnect, getDBConnection } from '@/connections/db';
import { seedFreshDatabase } from './seeder/core';
import { parseOptions, logSeedProgress, formatRange } from './seeder/utils';
import { AUTH_SIGNUP_BATCH_SIZE, DB_BULK_INSERT_CHUNK_SIZE } from './seeder/constants';

dotenv.config();

if (!process.env.DB_POOL_MAX) process.env.DB_POOL_MAX = process.env.SEED_DB_POOL_MAX || '2';
if (!process.env.DB_POOL_MIN) process.env.DB_POOL_MIN = process.env.SEED_DB_POOL_MIN || '0';
if (!process.env.DB_POOL_ACQUIRE_MS) process.env.DB_POOL_ACQUIRE_MS = process.env.SEED_DB_POOL_ACQUIRE_MS || '120000';
if (!process.env.DB_POOL_IDLE_MS) process.env.DB_POOL_IDLE_MS = process.env.SEED_DB_POOL_IDLE_MS || '10000';

async function main() {
  const options = parseOptions(process.argv.slice(2));
  logSeedProgress(
    `Resolved options: users=${formatRange(options.users)}, eventsPerUser=${formatRange(options.eventsPerUser)}, threadsPerEvent=${formatRange(options.threadsPerEvent)}, messagesPerThread=${formatRange(options.messagesPerThread)}, tagsPerEvent=${formatRange(options.tagsPerEvent)}, reuseExistingUsers=${options.reuseExistingUsers ? 'true' : 'false'}, reuseMaxUsers=${options.reuseMaxUsers ?? 'none'}, seedWorkers=${options.seedWorkers ?? process.env.SEED_WORKERS ?? 'auto'}, authBatchSize=${AUTH_SIGNUP_BATCH_SIZE}, dbBatchSize=${DB_BULK_INSERT_CHUNK_SIZE}, dbPoolMax=${process.env.DB_POOL_MAX}, dbPoolMin=${process.env.DB_POOL_MIN}`,
  );

  const sequelize = getDBConnection()!;

  try {
    await seedFreshDatabase(sequelize, options);
  } finally {
    logSeedProgress('Disconnecting database connection');
    await disconnect();
  }
}

main().catch((error) => {
  console.error('Fresh database seed failed:', error);
  disconnect().finally(() => process.exit(1));
});
