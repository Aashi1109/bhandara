import type { Job } from 'pg-boss';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BaseQueue } from '@/common/queues/base';

const bossMocks = vi.hoisted(() => ({
  createQueue: vi.fn(),
  getBoss: vi.fn(),
  schedule: vi.fn(),
  send: vi.fn(),
  work: vi.fn(),
}));

vi.mock('@/common/queues/boss', () => ({ getBoss: bossMocks.getBoss }));

type Payload = { id: string };

class TestQueue extends BaseQueue<Payload> {
  readonly name = 'test-queue';
  readonly handler = vi.fn<(payload: Payload, job: Job<Payload>) => Promise<void>>();

  protected handle(payload: Payload, job: Job<Payload>) {
    return this.handler(payload, job);
  }
}

describe('BaseQueue', () => {
  beforeEach(() => {
    bossMocks.getBoss.mockResolvedValue(bossMocks);
    bossMocks.send.mockResolvedValue('job-1');
  });

  it('creates the queue before publishing and forwards the job', async () => {
    const queue = new TestQueue();
    const payload = { id: 'payload-1' };
    const options = { singletonKey: 'payload-1' };

    await expect(queue.publish(payload, options)).resolves.toBe('job-1');

    expect(bossMocks.createQueue).toHaveBeenCalledWith(queue.name, expect.any(Object));
    expect(bossMocks.send).toHaveBeenCalledWith(queue.name, payload, options);
    expect(bossMocks.createQueue).toHaveBeenCalledBefore(bossMocks.send);
  });

  it('passes job data to the handler', async () => {
    const queue = new TestQueue();
    const job = { id: 'job-1', data: { id: 'payload-1' } } as Job<Payload>;
    bossMocks.work.mockImplementation(async (_name, _options, handler) => handler([job]));

    await queue.work();

    expect(queue.handler).toHaveBeenCalledWith(job.data, job);
  });

  it('lets handler errors reach pg-boss for retry', async () => {
    const queue = new TestQueue();
    const error = new Error('retry me');
    const job = { id: 'job-1', data: { id: 'payload-1' } } as Job<Payload>;
    queue.handler.mockRejectedValue(error);
    bossMocks.work.mockImplementation(async (_name, _options, handler) => handler([job]));

    await expect(queue.work()).rejects.toBe(error);
  });

  it('forwards cron schedules', async () => {
    const queue = new TestQueue();
    const payload = { id: 'payload-1' };
    const options = { tz: 'UTC' };

    await queue.schedule('0 * * * *', payload, options);

    expect(bossMocks.schedule).toHaveBeenCalledWith(queue.name, '0 * * * *', payload, options);
  });
});
