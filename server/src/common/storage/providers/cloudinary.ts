import CloudinaryService from '@/common/ccloudinary';
import { IMAGE_EAGER, VIDEO_EAGER, parseImageEagerResults, parseVideoEagerResults } from '../eager-transforms';
import type {
  IDeleteFileParams,
  IGetClientUploadParamsInput,
  IGetClientUploadParamsResult,
  IGetPublicUrlParams,
  IGetPublicUrlResult,
  IStorageProvider,
  IUploadFileParams,
  IUploadResult,
} from '../types';

export class CloudinaryStorageProvider implements IStorageProvider {
  private readonly client = new CloudinaryService();

  async uploadFile({
    bucket,
    path,
    base64FileData,
    mimeType,
    options = {},
  }: IUploadFileParams): Promise<IUploadResult> {
    const isVideo = mimeType.startsWith('video/');
    const eager = isVideo ? VIDEO_EAGER : IMAGE_EAGER;

    const res = await this.client.uploadFile({
      bucket,
      path,
      base64FileData,
      mimeType,
      options: {
        ...options,
        resource_type: isVideo ? 'video' : 'image',
        eager,
        eager_async: false,
      },
    });

    const eagerResults: Array<{ secure_url: string }> = (res as any).eager ?? [];

    if (isVideo) {
      return { path: res.public_id, ...parseVideoEagerResults(eagerResults) };
    }

    return { path: res.public_id, ...parseImageEagerResults(eagerResults) };
  }

  async deleteFile({ path, resourceType }: IDeleteFileParams): Promise<void> {
    const { error } = await this.client.deleteFile(path, resourceType);
    if (error) throw error;
  }

  async getPublicUrl({ path }: IGetPublicUrlParams): Promise<IGetPublicUrlResult> {
    return { signedUrl: this.client.getPublicUrl(path), expiresAt: -1 };
  }

  async getBulkPublicUrls({
    paths,
  }: {
    bucket: string;
    paths: string[];
    expiresIn?: number;
  }): Promise<Record<string, IGetPublicUrlResult>> {
    return paths.reduce(
      (acc, path) => {
        acc[path] = { signedUrl: this.client.getPublicUrl(path), expiresAt: -1 };
        return acc;
      },
      {} as Record<string, IGetPublicUrlResult>,
    );
  }

  async getClientUploadParams({
    bucket,
    path,
    resourceType,
    rid,
  }: IGetClientUploadParamsInput): Promise<IGetClientUploadParamsResult> {
    return this.client.getSignedUploadParams({ bucket, path, resourceType, rid });
  }
}
