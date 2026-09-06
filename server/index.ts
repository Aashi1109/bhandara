// Only import what's needed for tracing initialization
import './src/instrument';
import * as Sentry from '@sentry/node';
import {
  config,
  ensureDatabaseSchema,
  getDBConnection,
  getRedisConnection,
  initializeTracing,
  shutdownTracing,
} from '@/common';
import { stopBoss } from '@/common/queues/boss';

const apptype = config.appType;
const appname = config.appName;

async function startServer() {
  try {
    initializeTracing();
    const [db, redis] = await Promise.all([getDBConnection(), getRedisConnection()]);

    await Promise.all([await redis.ping(), await db!.ping()]);
    await ensureDatabaseSchema(db!);
    const { default: app } = await import(`./app/${apptype}`);
    app(appname);
  } catch (error) {
    console.error('Server failed to start', error);
    Sentry.captureException(error);
    Sentry.flush(2000).then(() => {
      process.exit(1);
    });
  }
}

startServer();

let shutdownPromise: Promise<void> | undefined;

const shutdown = async () => {
  shutdownPromise ??= (async () => {
    await Sentry.flush(2000).catch(() => false);
    await Promise.allSettled([stopBoss(), shutdownTracing()]);
    process.exit(0);
  })();

  await shutdownPromise;
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

process.on('uncaughtException', (error) => {
  console.error('Uncaught exception in server process', error);
  Sentry.captureException(error);
  Sentry.flush(2000).finally(() => {
    process.exit(1);
  });
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection in server process', reason);
  Sentry.captureException(reason);
  Sentry.flush(2000).finally(() => {
    process.exit(1);
  });
});
