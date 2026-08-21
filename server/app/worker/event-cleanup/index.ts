import { Worker } from 'bullmq';
import { WORKER_CONNECTION_CONFIG, logger } from '@/common';
import { getRedisConnection } from '@/common/connections/redis';
import { REDIS_CONNECTION_NAMES } from '@/common/constants';
import CloudinaryService from '@/common/ccloudinary';
import { MEDIA_FILE_BUCKET_NAME } from '@/features/media/constants';
import {
  CLEANUP_QUEUE_NAME,
  cleanupQueue,
  RESERVED_TID_SET_KEY,
  RESERVED_TID_TTL_SECONDS,
} from '@/common/queues/cleanup';

const cloudinaryService = new CloudinaryService();
const redis = getRedisConnection(REDIS_CONNECTION_NAMES.Cache);

const processor = async () => {
  const now = Date.now();
  const expiredTids = await redis.zrangebyscore(RESERVED_TID_SET_KEY, 0, now);

  if (expiredTids.length === 0) return;

  logger.info(`Event cleanup: removing ${expiredTids.length} orphaned event folders`);

  await Promise.all(
    expiredTids.map(async (tid) => {
      const prefix = `Zentry/${MEDIA_FILE_BUCKET_NAME}/${tid}`;
      await cloudinaryService.deleteFolderByPrefix(prefix);
      await redis.zrem(RESERVED_TID_SET_KEY, tid);
    }),
  );
};

async function registerRepeatableJob() {
  const jobs = await cleanupQueue.getRepeatableJobs();
  if (!jobs.some((j) => j.name === 'cleanup')) {
    await cleanupQueue.add('cleanup', {}, { repeat: { every: RESERVED_TID_TTL_SECONDS * 1000 } });
  }
}

registerRepeatableJob().catch((err) => logger.error('Event cleanup: failed to register repeatable job', err));

export default new Worker(CLEANUP_QUEUE_NAME, processor, {
  connection: WORKER_CONNECTION_CONFIG,
});
