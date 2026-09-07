import { CACHE_NAMESPACE_CONFIG } from '@/common/constants';
import SupabaseService from '@/supabase';
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

export class SupabaseStorageProvider implements IStorageProvider {
  private readonly client = new SupabaseService();

  async uploadFile({ bucket, path, base64FileData, mimeType, options = {} }: IUploadFileParams): Promise<IUploadResult> {
    const { data, error } = await this.client.uploadFile({ bucket, path, base64FileData, mimeType, options });
    if (error) throw error;
    return { path: data!.path };
  }

  async deleteFile({ bucket, path }: IDeleteFileParams): Promise<void> {
    const { error } = await this.client.deleteFile({ bucket, paths: [path] });
    if (error) throw error;
  }

  async getPublicUrl({ bucket, path, expiresIn = 3600 * 24, options = {} }: IGetPublicUrlParams): Promise<IGetPublicUrlResult> {
    const res = await this.client.getPublicUrl({ bucket, path, expiresIn, options });
    return {
      signedUrl: res.data!.signedUrl,
      expiresAt: new Date(Date.now() + expiresIn * 1000),
    };
  }

  async getBulkPublicUrls({
    bucket,
    paths,
    expiresIn = CACHE_NAMESPACE_CONFIG.Media.ttl,
  }: {
    bucket: string;
    paths: string[];
    expiresIn?: number;
  }): Promise<Record<string, IGetPublicUrlResult>> {
    const { data, error } = await this.client.getBulkPublicUrls({ bucket, paths, expiresIn });
    if (error) throw error;

    const expiresAt = new Date(Date.now() + expiresIn * 1000);
    return (data ?? []).reduce(
      (acc, url) => {
        if (url.path) {
          acc[url.path] = { signedUrl: url.signedUrl, expiresAt };
        }
        return acc;
      },
      {} as Record<string, IGetPublicUrlResult>,
    );
  }

  async getClientUploadParams({ bucket, path }: IGetClientUploadParamsInput): Promise<IGetClientUploadParamsResult> {
    const res = await this.client.getSignedUrlForUpload({ bucket, path });
    return {
      signedURL: res.data!.signedUrl,
      path,
      token: res.data!.token,
    };
  }
}
