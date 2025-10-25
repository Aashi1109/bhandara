import { initializeTracing, shutdownTracing } from "@/config/tracing.config";
import logger from "@/logger";

const workerType = process.env.WORKER_TYPE || "video-processor";

async function startWorker() {
  try {
    // Initialize tracing
    await initializeTracing();

    logger.info(`Starting worker: ${workerType}`);

    // Dynamically import the worker
    const workerModule = await import(`./${workerType}/worker`);

    logger.info(`${workerType} worker started and listening for jobs`);
  } catch (error) {
    logger.error(`Failed to start worker ${workerType}:`, error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on("SIGTERM", async () => {
  logger.info(`Shutting down ${workerType} worker...`);
  await shutdownTracing();
  process.exit(0);
});

process.on("SIGINT", async () => {
  logger.info(`Shutting down ${workerType} worker...`);
  await shutdownTracing();
  process.exit(0);
});

// Handle uncaught exceptions
process.on("uncaughtException", (error) => {
  logger.error(`Uncaught exception in ${workerType} worker:`, error);
  process.exit(1);
});

process.on("unhandledRejection", (reason, promise) => {
  logger.error(`Unhandled rejection in ${workerType} worker:`, {
    reason,
    promise,
  });
  process.exit(1);
});

// Start the worker
startWorker();
