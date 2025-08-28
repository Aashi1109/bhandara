import { IEvent, IMedia } from "@/definitions/types";
import { EMediaProvider } from "@/definitions/enums";
import { findAllWithPagination } from "@/utils/dbUtils";
import SupabaseService from "@/supabase";
import CloudinaryService from "@/ccloudinary";
import { validateMediaCreate, validateMediaUpdate } from "./validation";
import { MEDIA_BUCKET_CONFIG, MEDIA_PUBLIC_BUCKET_NAME } from "./constants";
import { Media } from "./model";
import { Event } from "../events/model";
import { isEmpty, omit } from "@/utils";
import {
  deleteMediaCache,
  getEventMediaCache,
  setEventMediaCache,
  setMediaCache,
} from "./helpers";
import { getMediaCache } from "./helpers";
import logger from "@/logger";
import { getUniqueFilename as getUniqueFilename } from "./utils";
import { BadRequestError } from "@/exceptions";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";

class MediaService {
  private readonly getCache = getMediaCache;
  private readonly setCache = setMediaCache;
  private readonly deleteCache = deleteMediaCache;
  private readonly _supabaseService = new SupabaseService();
  private readonly _cloudinaryService = new CloudinaryService();

  async _getByIdNoCache(id: string) {
    const res = await Media.findByPk(id, { raw: true });
    return res as any;
  }

  async getEventMedia(event: IEvent, limit: number | null = null) {
    const key = event.id + (limit ? `:${limit}` : "");
    const cached = await getEventMediaCache(key);
    if (cached) return cached;

    const mediaIds = event?.media || [];
    if (!mediaIds.length) return [];

    const data = await this.getMediaByIds(
      mediaIds.slice(0, limit || mediaIds.length) as unknown as string[]
    );

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
    if (provider === EMediaProvider.Cloudinary) {
      const data = await this._cloudinaryService.uploadFile({
        bucket,
        base64FileData: file,
        mimeType,
        path: getUniqueFilename(path),
        options,
      });

      return data;
    }

    const { data, error } = await this._supabaseService.uploadFile({
      bucket,
      base64FileData: file,
      mimeType,
      path: getUniqueFilename(path),
      options,
    });

    if (error) throw error;
    return data;
  }

  async deleteFile(
    bucket: string,
    path: string,
    provider: EMediaProvider = EMediaProvider.Supabase
  ) {
    if (provider === EMediaProvider.Cloudinary) {
      const { error } = await this._cloudinaryService.deleteFile(path);
      if (error) throw error;
      return { path, deleted: true };
    }

    const { error } = await this._supabaseService.deleteFile({
      bucket,
      paths: [path],
    });
    if (error) throw error;
    return { path, deleted: true };
  }

  async update<U extends Partial<IMedia>>(id: string, data: U) {
    const res = await validateMediaUpdate(data, async (validatedData) => {
      const row = await Media.findByPk(id);
      if (!row) throw new Error("Media not found");
      await row.update(validatedData as any);
      return row.toJSON() as any;
    });
    await this.deleteCache(id);
    return res;
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
        let {
          name: fileName,
          format,
          metadata,
          ...restOptions
        } = validatedData.options || {};

        const bucket = validatedData.bucket;

        const bucketConfig = MEDIA_BUCKET_CONFIG[validatedData.bucket];
        if (!bucketConfig) throw new Error("Bucket not found");
        if (validatedData.options.size > bucketConfig.maxSize)
          throw new BadRequestError("File size too large");

        const path = getUniqueFilename(validatedData.path);

        validatedData = omit(validatedData, ["path", "bucket", "options"]);
        restOptions = omit(restOptions, ["path"]);

        // create media record
        const createData = {
          url: path,
          storage: {
            metadata: {},
            bucket,
            provider: dataWithProvider.provider,
          },
          metadata: { ...metadata, format },
          mimeType: insertData.mimeType,
          name: fileName,
          ...restOptions,
          access: "public",
        };

        const creationData = await Media.create(createData as any, {
          transaction: tx,
          raw: true,
        });

        let signedUrl: any;
        if (dataWithProvider.provider === EMediaProvider.Cloudinary) {
          signedUrl = this._cloudinaryService.getSignedUploadParams({
            bucket,
            path,
            resourceType: restOptions.type,
            rid: creationData.id,
          });
        } else {
          const res = await this._supabaseService.getSignedUrlForUpload({
            path,
            bucket,
          });
          signedUrl = res.data;
        }

        delete signedUrl.token;
        return {
          row: creationData as IMedia,
          ...signedUrl,
        };
      })
    );
  }

  async getSignedUrlForPublicUpload({ path }: { path: string }) {
    const uniquePath = getUniqueFilename(path);
    const signedUrl = await this._supabaseService.getSignedUrlForUpload({
      bucket: MEDIA_PUBLIC_BUCKET_NAME,
      path: uniquePath,
    });
    delete signedUrl.data.token;
    return { path: uniquePath, ...signedUrl.data };
  }

  async uploadFileToSignedUrl({
    bucket,
    path,
    base64FileData,
    mimeType,
    token,
  }) {
    return this._supabaseService.uploadFileToSignedUrl({
      bucket,
      path,
      base64FileData,
      mimeType,
      token,
    });
  }

  async create<U extends Partial<Omit<IMedia, "id" | "updatedAt">>>(data: U) {
    const res = await validateMediaCreate(data, (validatedData) => {
      const { path, ...rest } = validatedData;
      return Media.create({
        ...rest,
        path: getUniqueFilename(path),
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
      const publicUrl = await this.getPublicUrl(
        res.url,
        res.storage.bucket,
        res.storage.provider
      );
      (res as any).publicUrl = publicUrl.signedUrl;
      (res as any).publicUrlExpiresAt = publicUrl.expiresAt;
      await this.setCache(id, res as any);
    }
    return res;
  }

  async getPublicUrl(
    path: string,
    bucket: string,
    provider: EMediaProvider = EMediaProvider.Supabase,
    options?: Record<string, any>
  ) {
    if (provider === EMediaProvider.Cloudinary) {
      const signedUrl = this._cloudinaryService.getPublicUrl(path);
      return {
        signedUrl,
        expiresAt: -1,
      };
    }

    const publicUrl = await this._supabaseService.getPublicUrl({
      bucket,
      path,
      expiresIn: 3600 * 24,
      options,
    });

    return {
      signedUrl: publicUrl.data.signedUrl,
      expiresAt: new Date(Date.now() + 3600 * 24 * 1000),
    };
  }

  async getBulkPublicUrls(
    paths: string[],
    bucket: string,
    expiresIn: number = CACHE_NAMESPACE_CONFIG.Media.ttl,
    provider: EMediaProvider = EMediaProvider.Supabase
  ) {
    if (provider === EMediaProvider.Cloudinary) {
      const urls = paths.map((p) => {
        const signedUrl = this._cloudinaryService.getPublicUrl(p);
        return { path: p, signedUrl, expiresAt: -1 };
      });

      return urls.reduce((acc, url) => {
        acc[url.path] = url;
        return acc;
      }, {} as Record<string, { signedUrl: string; expiresAt: Date | number }>);
    }

    const { data: publicUrls, error } =
      await this._supabaseService.getBulkPublicUrls({
        bucket,
        paths,
        expiresIn,
      });

    if (error) throw error;

    const publicUrlsWithExpiresAt = publicUrls.map((url) => {
      return {
        ...url,
        expiresAt: new Date(Date.now() + expiresIn * 1000),
      };
    });

    const mediaWithPublicUrls = publicUrlsWithExpiresAt.reduce((acc, url) => {
      acc[url.path] = url;
      return acc;
    }, {} as Record<string, { signedUrl: string; expiresAt: Date }>);

    return mediaWithPublicUrls;
  }

  async delete(id: string) {
    return Media.sequelize!.transaction(async (tx) => {
      const media = await Media.findByPk(id, { transaction: tx });
      if (!media) return null;
      await media.destroy({ transaction: tx });
      const deletionResult = await this.deleteFile(
        media.storage.bucket,
        media.url,
        media.storage.provider
      );
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
      { id: Array.from(filteredIds) },
      { limit: filteredIds.size }
    );
    const mediaData = { data: res.items } as { data: IMedia[] };
    if (!isEmpty(mediaData.data)) {
      // split according to buckets
      const bucketPathsMapping = (mediaData.data as IMedia[]).reduce(
        (acc, media) => {
          const key = `${media.storage.provider}:${media.storage.bucket}`;
          if (!acc[key]) {
            acc[key] = [];
          }
          acc[key].push(media.url);
          return acc;
        },
        {} as Record<string, string[]>
      );

      const bucketGroupedPublicUrls = await Promise.all(
        Object.entries(bucketPathsMapping).map(([key, paths]) => {
          const [provider, bucket] = key.split(":");
          return this.getBulkPublicUrls(
            paths,
            bucket,
            CACHE_NAMESPACE_CONFIG.Media.ttl,
            provider as EMediaProvider
          );
        })
      );

      const publicUrls = bucketGroupedPublicUrls.reduce(
        (acc, bucketPublicUrls) => {
          return {
            ...acc,
            ...bucketPublicUrls,
          };
        },
        {} as Record<
          string,
          { signedUrl: string; expiresAt: Date; error?: any }
        >
      );

      // Create a map of media data with their public URLs
      const mediaWithUrls = (mediaData.data as IMedia[]).reduce(
        (acc, media) => {
          const publicUrl = publicUrls[media.url];

          if (!publicUrl) {
            logger.error(`Public url not found for media ${media.id}`);
            return acc;
          }

          if ("error" in publicUrl && publicUrl.error) {
            logger.error("Error getting public url for media", {
              mediaId: media.id,
              error: publicUrl.error,
            });
            return acc;
          }

          acc[media.id] = {
            ...media,
            publicUrl: publicUrl?.signedUrl,
            publicUrlExpiresAt: publicUrl?.expiresAt,
          };
          return acc;
        },
        {}
      );

      // TODO: Need to be validated if this is required
      // await setMediaBulkCache(Object.values(mediaWithUrls));

      return mediaWithUrls;
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
    mediaSet.add(mediaId);
    const [, rows] = await Event.update(
      { media: Array.from(mediaSet) as any } as any,
      { where: { id: eventId }, returning: true }
    );
    return rows[0];
  }
}

export default MediaService;
