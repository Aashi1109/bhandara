import { PgBoss } from 'pg-boss';
import config from '../config';
import logger from '../logger';

export const PGBOSS_SCHEMA = process.env.PGBOSS_SCHEMA?.trim() || 'pgboss';

let bossPromise: Promise<PgBoss> | undefined;

const createBoss = async () => {
  if (!config.dbUrl) {
    throw new Error('DATABASE_URL is required to use job queues');
  }

  // Only worker processes run maintenance/cron polling; the API process publishes only.
  const isWorker = config.appType === 'worker';
  const poolMax = Number(process.env.PGBOSS_POOL_MAX || (isWorker ? 5 : 2));

  const boss = new PgBoss({
    connectionString: config.dbUrl,
    schema: PGBOSS_SCHEMA,
    max: Number.isFinite(poolMax) && poolMax > 0 ? poolMax : 2,
    application_name: `${config.infrastructure.serviceName}-pgboss`,
    supervise: isWorker,
    schedule: isWorker,
  });

  boss.on('error', (error) => logger.error('pg-boss error', error));
  boss.on('warning', (warning) => logger.warn('pg-boss warning', warning));

  await boss.start();
  logger.info('pg-boss started', { schema: PGBOSS_SCHEMA, supervise: isWorker });

  return boss;
};

/** Shared pg-boss client for the process. Started on first use. */
export const getBoss = () => {
  bossPromise ??= createBoss().catch((error) => {
    // let a later call retry instead of caching the failure forever
    bossPromise = undefined;
    throw error;
  });

  return bossPromise;
};

export const stopBoss = async () => {
  if (!bossPromise) return;

  const pending = bossPromise;
  bossPromise = undefined;

  const boss = await pending.catch(() => null);
  await boss?.stop({ graceful: true, close: true }).catch((error) => logger.error('pg-boss stop failed', error));
};
