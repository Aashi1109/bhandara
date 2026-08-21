import { type UploadApiResponse, type UploadApiOptions, v2 as cloudinary } from 'cloudinary';
import config from '../config';
import { IMAGE_EAGER_STRING } from '../storage/eager-transforms';

const CLOUDINARY_RESOURCE_TYPES = ['image', 'video', 'raw'] as const;
type CloudinaryResourceType = (typeof CLOUDINARY_RESOURCE_TYPES)[number];

cloudinary.config({
  cloud_name: config.cloudinary.cloudName,
  api_key: config.cloudinary.apiKey,
  api_secret: config.cloudinary.apiSecret,
  secure: config.cloudinary.secure,
});

const getCloudinaryResourceType = (resourceType?: string | null): CloudinaryResourceType => {
  if (!resourceType) return 'image';

  if (
    resourceType === 'video' ||
    resourceType.startsWith('video/') ||
    resourceType === 'audio' ||
    resourceType.startsWith('audio/')
  ) {
    return 'video';
  }

  if (resourceType === 'raw' || resourceType === 'document' || resourceType.startsWith('application/')) {
    return 'raw';
  }

  return 'image';
};

class CloudinaryService {
  private readonly baseFolderPath = `Zentry/`;
  private readonly uploadPreset = config.cloudinary.uploadPreset;

  async uploadFile({
    bucket,
    path,
    base64FileData,
    mimeType,
    options = {},
  }: {
    bucket: string;
    path: string;
    base64FileData: string;
    mimeType: string;
    options?: UploadApiOptions;
  }): Promise<UploadApiResponse> {
    const fileData = `data:${mimeType};base64,${base64FileData}`;

    const res = await cloudinary.uploader.upload(fileData, {
      folder: bucket,
      public_id: path,
      resource_type: 'image',
      ...options,
    });
    return res;
  }

  async deleteFile(publicId: string, resourceType?: string | null) {
    try {
      const res = await cloudinary.uploader.destroy(publicId, {
        invalidate: true,
        resource_type: getCloudinaryResourceType(resourceType),
      });
      return { data: res };
    } catch (error) {
      return { data: null as any, error };
    }
  }

  getPublicUrl(publicId: string, options: Record<string, any> = {}) {
    return cloudinary.url(publicId, { secure: true, ...options });
  }

  async deleteFolderByPrefix(prefix: string): Promise<void> {
    await Promise.all(
      CLOUDINARY_RESOURCE_TYPES.map((resourceType) =>
        cloudinary.api.delete_resources_by_prefix(prefix, {
          invalidate: true,
          resource_type: resourceType,
        }),
      ),
    );
    await cloudinary.api.delete_folder(prefix).catch(() => {});
  }

  getSignedUploadParams({
    bucket,
    path,
    resourceType,
    rid,
  }: {
    bucket: string;
    path: string;
    resourceType: string;
    rid: string;
  }) {
    const timestamp = Math.floor(Date.now() / 1000);
    const isImage = resourceType === 'image';

    const paramsToSign: Record<string, any> = {
      timestamp,
      folder: `${this.baseFolderPath}${bucket}`,
      public_id: path,
      context: `rid=${rid}|provider=cloudinary`,
      ...(this.uploadPreset && { upload_preset: this.uploadPreset }),
      ...(isImage && {
        eager: IMAGE_EAGER_STRING,
        eager_async: '1',
      }),
    };
    const signature = cloudinary.utils.api_sign_request(paramsToSign, config.cloudinary.apiSecret as string);

    const url = `https://api.cloudinary.com/v1_1/${config.cloudinary.cloudName}/${resourceType}/upload`;

    const uploadParams: Record<string, string> = {
      ...Object.fromEntries(Object.entries(paramsToSign).map(([k, v]) => [k, String(v)])),
      signature,
      api_key: config.cloudinary.apiKey ?? '',
    };
    return {
      signedURL: url,
      uploadParams,
      path: `${this.baseFolderPath}${bucket}/${path}`,
    };
  }
}

export default CloudinaryService;
