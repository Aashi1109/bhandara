import { CLEANUP_CRON, cleanupQueue } from '@/common/queues/cleanup';

export default (async () => {
  await cleanupQueue.schedule(CLEANUP_CRON);
  await cleanupQueue.work();
})();
