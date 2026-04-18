import { logger } from '@/src/common';

export default async function run(appName: string) {
  try {
    logger.info(`Starting worker: ${appName}`);

    await import(`./${appName}`);

    logger.info(`${appName} worker started and listening for jobs`);
  } catch (error) {
    logger.error(`Failed to start worker ${appName}:`, error);
    process.exit(1);
  }
}
