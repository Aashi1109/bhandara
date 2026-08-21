import { logger } from '@/common';

export default async function run(appName: string) {
  try {
    logger.info(`Starting worker: ${appName}`);

    const worker = await import(`./${appName}`);
    await worker.default;

    logger.info(`${appName} worker started and listening for jobs`);
  } catch (error) {
    logger.error(`Failed to start worker ${appName}:`, error);
    process.exit(1);
  }
}
