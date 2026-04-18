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
} from '@/src/common';

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

process.on('SIGTERM', () => {
  Sentry.flush(2000)
    .then(() => {
      return shutdownTracing();
    })
    .finally(() => {
      process.exit(0);
    });
});

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
