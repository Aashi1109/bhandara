import { initializeTracing, shutdownTracing } from "@/config/tracing.config";
import logger from "@/logger";
import videoWorker from "./index";

// Initialize tracing for the video worker
initializeTracing().then(() => {
  logger.info("Video worker started and listening for jobs");
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  logger.info("Shutting down video worker...");
  await videoWorker.close();
  await shutdownTracing();
  process.exit(0);
});

process.on("SIGINT", async () => {
  logger.info("Shutting down video worker...");
  await videoWorker.close();
  await shutdownTracing();
  process.exit(0);
});

// Handle uncaught exceptions
process.on("uncaughtException", (error) => {
  logger.error("Uncaught exception in video worker:", error);
  process.exit(1);
});

process.on("unhandledRejection", (reason, promise) => {
  logger.error("Unhandled rejection in video worker:", { reason, promise });
  process.exit(1);
});
