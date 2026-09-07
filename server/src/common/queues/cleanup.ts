import CloudinaryService from '../ccloudinary';
import { getRedisConnection } from '../connections/redis';
import { REDIS_CONNECTION_NAMES } from '../constants';
import { MEDIA_FILE_BUCKET_NAME } from '@/features/media/constants';
import logger from '../logger';
import { BaseQueue, type QueueConfig } from './base';

export const CLEANUP_QUEUE_NAME = 'event-cleanup';

export const RESERVED_TID_KEY_PREFIX = 'event:reserved:';
export const RESERVED_TID_SET_KEY = 'event:reserved:set';
export const RESERVED_TID_TTL_SECONDS = 3600;

/** Hourly, matching RESERVED_TID_TTL_SECONDS. */
export const CLEANUP_CRON = '0 * * * *';

class CleanupQueue extends BaseQueue {
  readonly name = CLEANUP_QUEUE_NAME;

  protected get queueConfig(): QueueConfig {
    return {
      retryLimit: 2,
      retryDelay: 60,
      retryBackoff: true,
      expireInSeconds: 600,
      // a stale sweep is worthless once the next one is due
      policy: 'exclusive',
    };
  }

  protected async handle() {
    const redis = getRedisConnection(REDIS_CONNECTION_NAMES.Cache);
    const cloudinaryService = new CloudinaryService();

    const expiredTids = await redis.zrangebyscore(RESERVED_TID_SET_KEY, 0, Date.now());
    if (expiredTids.length === 0) return;

    logger.info(`Event cleanup: removing ${expiredTids.length} orphaned event folders`);

    await Promise.all(
      expiredTids.map(async (tid) => {
        const prefix = `Zentry/${MEDIA_FILE_BUCKET_NAME}/${tid}`;
        await cloudinaryService.deleteFolderByPrefix(prefix);
        await redis.zrem(RESERVED_TID_SET_KEY, tid);
      }),
    );
  }
}

export const cleanupQueue = new CleanupQueue();
