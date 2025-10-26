import createServer from "@/app";
import config from "@/config";
import { initializeTracing, shutdownTracing } from "@/config/tracing.config";
import logger from "@/logger";
import { initializeSocket } from "@/socket";
import { initializeMediaRealtime } from "@/supabase/realtime";
import http from "http";
import { getDBConnection } from "./connections/db";
import { getRedisConnection } from "./connections/redis";

initializeTracing().then(async () => {
  const [db, redis] = await Promise.all([
    getDBConnection(),
    getRedisConnection(),
  ]);

  await Promise.all([await redis.ping(), await db.ping()]);

  const app = createServer();

  const httpServer = http.createServer(app);
  initializeSocket(httpServer);
  initializeMediaRealtime();

  httpServer.listen(config.port, () => {
    logger.info(`Server is running on port ${config.port}`);
  });
});

process.on("SIGTERM", () => {
  shutdownTracing().finally(() => {
    process.exit(0);
  });
});
