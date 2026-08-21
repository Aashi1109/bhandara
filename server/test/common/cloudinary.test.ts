import { beforeEach, describe, expect, it, vi } from 'vitest';
import CloudinaryService from '@/common/ccloudinary';

const cloudinaryMocks = vi.hoisted(() => ({
  config: vi.fn(),
  deleteFolder: vi.fn(),
  deleteResourcesByPrefix: vi.fn(),
  destroy: vi.fn(),
  upload: vi.fn(),
  signRequest: vi.fn(),
}));

vi.mock('cloudinary', () => ({
  v2: {
    api: {
      delete_folder: cloudinaryMocks.deleteFolder,
      delete_resources_by_prefix: cloudinaryMocks.deleteResourcesByPrefix,
    },
    config: cloudinaryMocks.config,
    uploader: {
      destroy: cloudinaryMocks.destroy,
      upload: cloudinaryMocks.upload,
    },
    utils: {
      api_sign_request: cloudinaryMocks.signRequest,
    },
  },
}));

describe('CloudinaryService', () => {
  beforeEach(() => {
    cloudinaryMocks.deleteFolder.mockResolvedValue({});
    cloudinaryMocks.deleteResourcesByPrefix.mockResolvedValue({});
    cloudinaryMocks.destroy.mockResolvedValue({ result: 'ok' });
  });

  it('deletes video media with Cloudinary video resource type', async () => {
    const service = new CloudinaryService();

    await service.deleteFile('Zentry/media/event-video', 'video');

    expect(cloudinaryMocks.destroy).toHaveBeenCalledWith('Zentry/media/event-video', {
      invalidate: true,
      resource_type: 'video',
    });
  });

  it('deletes all Cloudinary resource types when removing a reservation folder', async () => {
    const service = new CloudinaryService();

    await service.deleteFolderByPrefix('Zentry/media/reserved-tid');

    expect(cloudinaryMocks.deleteResourcesByPrefix).toHaveBeenCalledTimes(3);
    expect(cloudinaryMocks.deleteResourcesByPrefix).toHaveBeenCalledWith('Zentry/media/reserved-tid', {
      invalidate: true,
      resource_type: 'image',
    });
    expect(cloudinaryMocks.deleteResourcesByPrefix).toHaveBeenCalledWith('Zentry/media/reserved-tid', {
      invalidate: true,
      resource_type: 'video',
    });
    expect(cloudinaryMocks.deleteResourcesByPrefix).toHaveBeenCalledWith('Zentry/media/reserved-tid', {
      invalidate: true,
      resource_type: 'raw',
    });
    expect(cloudinaryMocks.deleteFolder).toHaveBeenCalledWith('Zentry/media/reserved-tid');
  });
});
