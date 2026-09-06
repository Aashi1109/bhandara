import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  addVideoJob: vi.fn(),
  cleanupCron: 'test-cleanup-cron',
  cleanupSchedule: vi.fn(),
  cleanupWork: vi.fn(),
  getMediaById: vi.fn(),
  videoWork: vi.fn(),
}));

vi.mock('@/common/queues/video', () => ({
  addVideoJob: mocks.addVideoJob,
  videoQueue: { work: mocks.videoWork },
}));

vi.mock('@/common/queues/cleanup', () => ({
  CLEANUP_CRON: mocks.cleanupCron,
  cleanupQueue: {
    schedule: mocks.cleanupSchedule,
    work: mocks.cleanupWork,
  },
}));

vi.mock('@/features/media/service', () => ({
  default: class {
    getById = mocks.getMediaById;
  },
  toMediaPublic: vi.fn(),
}));

describe('worker boundaries', () => {
  beforeEach(() => vi.resetModules());

  it('starts only the video queue from the video worker', async () => {
    const worker = await import('@app/worker/video-processor');

    await worker.default;

    expect(mocks.videoWork).toHaveBeenCalledOnce();
    expect(mocks.cleanupWork).not.toHaveBeenCalled();
  });

  it('schedules cleanup before starting the cleanup worker', async () => {
    const worker = await import('@app/worker/event-cleanup');

    await worker.default;

    expect(mocks.cleanupSchedule).toHaveBeenCalledWith(mocks.cleanupCron);
    expect(mocks.cleanupWork).toHaveBeenCalledOnce();
    expect(mocks.cleanupSchedule).toHaveBeenCalledBefore(mocks.cleanupWork);
    expect(mocks.videoWork).not.toHaveBeenCalled();
  });

  it('enqueues a current video record after upload completion', async () => {
    const { onUploadComplete } = await import('@/features/media/controller');
    const media = { id: 'media-1', mimeType: 'video/mp4' };
    const json = vi.fn();
    const status = vi.fn(() => ({ json }));
    mocks.getMediaById.mockResolvedValue(media);

    await onUploadComplete(
      { body: { id: media.id, eventId: 'event-1' } } as Parameters<typeof onUploadComplete>[0],
      { status } as unknown as Parameters<typeof onUploadComplete>[1],
    );

    expect(mocks.getMediaById).toHaveBeenCalledWith(media.id);
    expect(mocks.addVideoJob).toHaveBeenCalledWith(media.id, 'event-1');
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({ data: { queued: true } });
  });
});
