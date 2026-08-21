import { Queue } from 'bullmq';
import { WORKER_CONNECTION_CONFIG } from '../config';

export const CLEANUP_QUEUE_NAME = 'event-cleanup';

export const RESERVED_TID_KEY_PREFIX = 'event:reserved:';
export const RESERVED_TID_SET_KEY = 'event:reserved:set';
export const RESERVED_TID_TTL_SECONDS = 3600;

export const cleanupQueue = new Queue(CLEANUP_QUEUE_NAME, {
  connection: WORKER_CONNECTION_CONFIG,
});
