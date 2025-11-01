// Only import what's needed for tracing initialization
import "@/instrument";
import { initializeTracing, shutdownTracing } from "@/config/tracing.config";
import Sentry from "@sentry/node";

async function startServer() {
  try {
    // Initialize OpenTelemetry FIRST, before any other imports
    await initializeTracing();

    // Now dynamically import modules that need instrumentation
    const [
      { default: createServer },
      config,
      logger,
      { initializeSocket },
      { initializeMediaRealtime },
      { getDBConnection },
      { getRedisConnection },
    ] = await Promise.all([
      import("@/app"),
      import("@/config"),
      import("@/logger"),
      import("@/socket"),
      import("@/supabase/realtime"),
      import("./connections/db"),
      import("./connections/redis"),
    ]);

    const http = await import("http");

    const [db, redis] = await Promise.all([
      getDBConnection(),
      getRedisConnection(),
    ]);

    await Promise.all([await redis.ping(), await db.ping()]);

    const app = createServer();

    const httpServer = http.createServer(app);
    initializeSocket(httpServer);
    initializeMediaRealtime();

    httpServer.listen(config.default.port, () => {
      logger.default.info(`Server is running on port ${config.default.port}`);
    });
  } catch (error) {
    Sentry.captureException(error);
    Sentry.flush(2000).then(() => {
      process.exit(1);
    });
  }
}

startServer();

process.on("SIGTERM", () => {
  Sentry.flush(2000)
    .then(() => {
      return shutdownTracing();
    })
    .finally(() => {
      process.exit(0);
    });
});
