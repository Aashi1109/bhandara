import createServer from "@/app";
import config from "@/config";
import { initializeTracing, shutdownTracing } from "@/config/tracing.config";
import logger from "@/logger";
import { initializeSocket } from "@/socket";
import { initializeMediaRealtime } from "@/supabase/realtime";
import http from "http";

initializeTracing().then(() => {
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
