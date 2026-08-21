import type { Job, PgBoss, Queue, ScheduleOptions, SendOptions, WorkOptions } from 'pg-boss';
import { getBoss } from './boss';
import logger from '../logger';

export type QueueConfig = Omit<Queue, 'name'>;

/**
 * Shared plumbing for every pg-boss queue: client bootstrap, idempotent queue
 * creation, publishing, cron scheduling and worker registration.
 *
 * A concrete queue only declares its `name` and implements `handle`. Override
 * `queueConfig`/`workOptions` to tune retries, expiry or concurrency.
 */
export abstract class BaseQueue<TPayload extends object = object> {
  abstract readonly name: string;

  private ready?: Promise<PgBoss>;

  /** Queue-level defaults, applied on creation. */
  protected get queueConfig(): QueueConfig {
    return {
      retryLimit: 3,
      retryDelay: 30,
      retryBackoff: true,
      expireInSeconds: 900,
    };
  }

  /** Consumer-level options for `work()`. */
  protected get workOptions(): WorkOptions {
    return {
      batchSize: 1,
      localConcurrency: 1,
      pollingIntervalSeconds: 5,
    };
  }

  /** Business logic for a single job. Throw to trigger a retry. */
  protected abstract handle(payload: TPayload, job: Job<TPayload>): Promise<void>;

  private ensureQueue() {
    this.ready ??= (async () => {
      const boss = await getBoss();
      await boss.createQueue(this.name, this.queueConfig);
      return boss;
    })().catch((error) => {
      this.ready = undefined;
      throw error;
    });

    return this.ready;
  }

  /** Enqueue a job. Returns the job id, or null when deduplicated by pg-boss. */
  async publish(payload: TPayload, options: SendOptions = {}) {
    const boss = await this.ensureQueue();
    const jobId = await boss.send(this.name, payload, options);

    if (!jobId) {
      logger.debug('Job not enqueued (deduplicated)', { queue: this.name });
    }

    return jobId;
  }

  /** Register/replace a cron schedule for this queue. Idempotent. */
  async schedule(cron: string, payload?: TPayload, options: ScheduleOptions = {}) {
    const boss = await this.ensureQueue();
    await boss.schedule(this.name, cron, payload ?? null, options);
    logger.info('Queue schedule registered', { queue: this.name, cron });
  }

  /** Start consuming jobs in the current process. */
  async work() {
    const boss = await this.ensureQueue();

    await boss.work<TPayload>(this.name, this.workOptions, async (jobs) => {
      for (const job of jobs) {
        try {
          await this.handle(job.data, job);
        } catch (error) {
          logger.error('Job failed', { queue: this.name, jobId: job.id, error });
          throw error;
        }
      }
    });

    logger.info('Queue worker listening', { queue: this.name });
  }
}
