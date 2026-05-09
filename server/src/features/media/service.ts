import type { IEvent, IMedia } from '@/common/definitions/types';
import { EMediaProvider } from '@/common/definitions/enums';
import { findAllWithPagination, findByPkOrThrow } from '@/common/utils/dbUtils';
import SupabaseService from '@/supabase';
import { StorageFactory } from '@/common/storage';
import { validateMediaCreate } from './validation';
import { MEDIA_BUCKET_CONFIG, MEDIA_PUBLIC_BUCKET_NAME } from './constants';
import { Media } from './model';
import { Event } from '../events/model';
import { isEmpty, omit } from '@/common/utils';
import { deleteMediaCache, getEventMediaCache, setEventMediaCache, setMediaCache, getMediaCache } from './helpers';
import logger from '@/common/logger';
import { getUniqueFilename as getUniqueFilename } from './utils';
import { BadRequestError, NotFoundError } from '@/common/exceptions';
import { CACHE_NAMESPACE_CONFIG } from '@/common/constants';
import EntityStatsService from '@/features/stats/service';

class MediaService {
  private readonly getCache = getMediaCache;
  private readonly setCache = setMediaCache;
  private readonly deleteCache = deleteMediaCache;
  private readonly entityStatsService = new EntityStatsService();

  // Retained for Supabase-specific signed upload completion flow
  private readonly _supabaseService = new SupabaseService();

  async _getByIdNoCache(id: string) {
    const res = await Media.findByPk(id, { raw: true });
    return res as any;
  }

  async getEventMedia(event: IEvent, limit: number | null = null) {
    const key = event.id + (limit ? `:${limit}` : '');
    const cached = await getEventMediaCache(key);
    if (cached) return cached;

    const mediaIds = event?.media || [];
    if (!mediaIds.length) return [];

    const data = await this.getMediaByIds(mediaIds.slice(0, limit || mediaIds.length) as unknown as string[]);

    const values = Object.values(data);
    if (values.length > 0) await setEventMediaCache(key, values as IMedia[]);
    return values;
  }

  async uploadFile({
    path,
    bucket,
    file,
    mimeType,
    provider = EMediaProvider.Supabase,
    options,
  }: {
    file: string;
    path: string;
    bucket: string;
    mimeType: string;
    provider?: EMediaProvider;
    options?: Record<string, any>;
  }) {
    return StorageFactory.get(provider).uploadFile({
      bucket,
      base64FileData: file,
      mimeType,
      path: getUniqueFilename(path),
      options,
    });
  }

  async deleteFile(bucket: string, path: string, provider: EMediaProvider = EMediaProvider.Supabase) {
    await StorageFactory.get(provider).deleteFile({ bucket, path });
    return { path, deleted: true };
  }

  async update<U extends Partial<IMedia>>(id: string, data: U) {
    const row = await findByPkOrThrow(Media, id, 'Media');
    await row.update(data as any);
    await this.deleteCache(id);
    return row.toJSON() as any;
  }

  async getSignedUrlForUpload(insertData: {
    bucket: string;
    path: string;
    options: Record<string, any>;
    mimeType: string;
    provider?: EMediaProvider;
  }) {
    const dataWithProvider = {
      provider: insertData.provider || EMediaProvider.Supabase,
      ...insertData,
    };
    return validateMediaCreate(dataWithProvider, (validatedData) =>
      Media.sequelize!.transaction(async (tx) => {
        const { name: fileName, format, metadata, ...initialRestOptions } = validatedData.options || {};
        let restOptions = initialRestOptions;

        const { bucket } = validatedData;

        const bucketConfig = (MEDIA_BUCKET_CONFIG as Record<string, { accept: string[]; maxSize: number }>)[
          validatedData.bucket
        ];
        if (!bucketConfig) throw new NotFoundError('Bucket not found');
        if (validatedData.options.size > bucketConfig.maxSize) throw new BadRequestError('File size too large');

        const path = getUniqueFilename(validatedData.path);

        validatedData = omit(validatedData, ['path', 'bucket', 'options']);
        restOptions = omit(restOptions, ['path']);

        const createData = {
          url: path,
          provider: dataWithProvider.provider,
          storage: {
            metadata: {},
            bucket,
          },
          metadata: { ...metadata, format },
          mimeType: insertData.mimeType,
          name: fileName,
          ...restOptions,
          access: 'public',
        };

        const creationData = await Media.create(createData as any, {
          transaction: tx,
          raw: true,
        });

        const signedUrl = await StorageFactory.get(dataWithProvider.provider).getClientUploadParams({
          bucket,
          path,
          resourceType: restOptions.type,
          rid: creationData.id,
        });

        if (signedUrl) delete (signedUrl as any).token;
        return {
          row: creationData as IMedia,
          ...signedUrl,
        };
      }),
    );
  }

  async getSignedUrlForPublicUpload({ path }: { path: string }) {
    const uniquePath = getUniqueFilename(path);
    const res = await this._supabaseService.getSignedUrlForUpload({
      bucket: MEDIA_PUBLIC_BUCKET_NAME,
      path: uniquePath,
    });
    if (res.data) delete (res.data as any).token;
    return { path: uniquePath, ...res.data };
  }

  async uploadFileToSignedUrl({
    bucket,
    path,
    base64FileData,
    mimeType,
    token,
  }: {
    bucket: string;
    path: string;
    base64FileData: string;
    mimeType: string;
    token: string;
  }) {
    return this._supabaseService.uploadFileToSignedUrl({
      bucket,
      path,
      base64FileData,
      mimeType,
      token,
    });
  }

  async create<U extends Partial<Omit<IMedia, 'id' | 'updatedAt'>>>(data: U) {
    const res = await validateMediaCreate(data, (validatedData) => {
      const { path, ...rest } = validatedData;
      return Media.create({
        ...rest,
        path: getUniqueFilename(path!),
      } as any);
    });
    const created = res as any;
    if (created) {
      const row = created.dataValues ? created.dataValues : created;
      await this.setCache(row.id, row as IMedia);
    }
    return res;
  }

  async getById(id: string): Promise<IMedia | null> {
    const cached = await this.getCache(id);
    if (cached) return cached;

    const res = (await Media.findByPk(id, { raw: true })) as IMedia | null;
    if (res) {
      const publicUrl = await this.getPublicUrl(res.url, res.storage.bucket, res.provider);
      (res as any).publicUrl = publicUrl.signedUrl;
      (res as any).publicUrlExpiresAt = publicUrl.expiresAt;
      await this.setCache(id, res);
    }
    return res;
  }

  async getPublicUrl(
    path: string,
    bucket: string,
    provider: EMediaProvider = EMediaProvider.Supabase,
    options?: Record<string, any>,
  ) {
    return StorageFactory.get(provider).getPublicUrl({ bucket, path, options });
  }

  async getBulkPublicUrls(
    paths: string[],
    bucket: string,
    expiresIn: number = CACHE_NAMESPACE_CONFIG.Media.ttl,
    provider: EMediaProvider = EMediaProvider.Supabase,
  ) {
    return StorageFactory.get(provider).getBulkPublicUrls({ bucket, paths, expiresIn });
  }

  async delete(id: string) {
    return Media.sequelize!.transaction(async (tx) => {
      const media = await Media.findByPk(id, { transaction: tx });
      if (!media) return null;
      await media.destroy({ transaction: tx });
      const deletionResult = await this.deleteFile(media.storage.bucket, media.url, media.provider);
      await this.deleteCache(id);
      logger.debug(`Deleted media ${id}`, { deletionResult });
      return media;
    }) as any;
  }

  async getMediaByIds(ids: string[]): Promise<Record<string, IMedia>> {
    const filteredIds = new Set(ids.filter((id) => !!id));

    if (filteredIds.size === 0) return {};

    const res = await findAllWithPagination(
      Media,
      { where: { id: Array.from(filteredIds) } },
      { limit: filteredIds.size },
    );
    const mediaData = { data: res.items } as { data: IMedia[] };
    if (!isEmpty(mediaData.data)) {
      const bucketPathsMapping = (mediaData.data as IMedia[]).reduce(
        (acc, media) => {
          const key = `${media.provider}:${media.storage.bucket}`;
          if (!acc[key]) acc[key] = [];
          acc[key].push(media.url);
          return acc;
        },
        {} as Record<string, string[]>,
      );

      const bucketGroupedPublicUrls = await Promise.all(
        Object.entries(bucketPathsMapping).map(([key, paths]) => {
          const [provider, bucket] = key.split(':');
          return this.getBulkPublicUrls(paths, bucket, CACHE_NAMESPACE_CONFIG.Media.ttl, provider as EMediaProvider);
        }),
      );

      const publicUrls = bucketGroupedPublicUrls.reduce(
        (acc, bucketPublicUrls) => ({ ...acc, ...bucketPublicUrls }),
        {} as Record<string, { signedUrl: string; expiresAt: Date | number; error?: any }>,
      );

      return (mediaData.data as IMedia[]).reduce(
        (acc, media) => {
          const publicUrl = publicUrls[media.url];

          if (!publicUrl) {
            logger.error(`Public url not found for media ${media.id}`);
            return acc;
          }

          if ('error' in publicUrl && publicUrl.error) {
            logger.error('Error getting public url for media', { mediaId: media.id, error: publicUrl.error });
            return acc;
          }

          acc[media.id] = {
            ...media,
            publicUrl: publicUrl?.signedUrl,
            publicUrlExpiresAt: publicUrl?.expiresAt,
          };
          return acc;
        },
        {} as Record<string, any>,
      );
    }
    return {};
  }

  async getEventMediaJunctionRow(eventId: string, mediaId: string) {
    const event = (await Event.findByPk(eventId, { raw: true })) as any;
    const exists = (event?.media || []).includes(mediaId);
    return exists ? { eventId, mediaId } : null;
  }

  async createEventMediaJunctionRow(eventId: string, mediaId: string) {
    const event = (await Event.findByPk(eventId, { raw: true })) as any;
    const mediaSet = new Set((event?.media || []) as string[]);
    const alreadyPresent = mediaSet.has(mediaId);
    mediaSet.add(mediaId);
    const [, rows] = await Event.update({ media: Array.from(mediaSet) as any } as any, {
      where: { id: eventId },
      returning: true,
    });
    if (!alreadyPresent && rows[0]) {
      await this.entityStatsService.syncEventRowStats(rows[0].toJSON() as IEvent);
    }
    return rows[0];
  }
}

export function toMediaPublic(media: IMedia): {
  id: string;
  type: string;
  url: string;
  publicUrl: string | undefined;
  publicUrlExpiresAt: Date | number | undefined;
  thumbnail: string | null | undefined;
  thumbnails: IMedia['thumbnails'];
  variants: IMedia['variants'];
  streamUrl: string | null | undefined;
  caption: string | null | undefined;
  name: string;
} {
  return {
    id: media.id,
    type: media.type,
    url: media.url,
    publicUrl: media.publicUrl,
    publicUrlExpiresAt: media.publicUrlExpiresAt,
    thumbnail: media.thumbnail,
    thumbnails: media.thumbnails,
    variants: media.variants,
    streamUrl: media.streamUrl,
    caption: media.caption,
    name: media.name,
  };
}

export default MediaService;
