import type { ICustomRequest } from '@/common/definitions/types';
import type { Response } from 'express';
import MediaService, { toMediaPublic } from './service';
import { BadRequestError, NotFoundError } from '@/common/exceptions';
import { isEmpty, pick } from '@/common/utils';
import type { EMediaProvider } from '@/common/definitions/enums';
import logger from '@/common/logger';
import { addVideoJob } from '@/common/queues/video';
import { parseImageEagerResults } from '@/common/storage/eager-transforms';
import { DEFAULT_MEDIA_PROVIDER } from './constants';

const mediaService = new MediaService();
const asString = (value: unknown): string | undefined => {
  if (typeof value === 'string') return value;
  if (Array.isArray(value)) {
    const first = value[0];
    return typeof first === 'string' ? first : undefined;
  }
  return undefined;
};

export const uploadFile = async (req: ICustomRequest, res: Response) => {
  const { file, path, bucket, mimeType, provider, format, ...rest } = req.body;

  const uploadPath = `${req.user.id}/${path}`;
  const uploadRes = (await mediaService.uploadFile({
    file,
    path: uploadPath,
    bucket,
    provider,
    mimeType,
    options: {
      uploader: req.user.id,
      ...rest,
    },
  })) as any;

  return res.status(201).json({ data: uploadRes?.data });
};

const sanitizeParentPath = (parentPath: unknown, fallback: string): string => {
  if (typeof parentPath !== 'string' || parentPath.trim() === '') return fallback;
  // Reject any path traversal attempts
  if (/\.\./.test(parentPath) || /[/\\]/.test(parentPath)) return fallback;
  return parentPath;
};

export const getSignedUploadUrl = async (req: ICustomRequest, res: Response) => {
  const { path, bucket, mimeType, parentPath, format, ...rest } = req.body;
  let provider = req.body.provider as string | undefined;
  provider ??= DEFAULT_MEDIA_PROVIDER;

  const uploadPath = `${sanitizeParentPath(parentPath, req.user.id)}/${path}`;
  const insertData = {
    path: uploadPath,
    bucket,
    provider: provider as EMediaProvider | undefined,
    mimeType,
    options: {
      uploader: req.user.id,
      ...rest,
      format,
    },
  };

  const responseSignedURL = await mediaService.getSignedUrlForUpload(insertData);

  return res.status(200).json({ data: responseSignedURL });
};

export const getPublicSignedUploadUrl = async (req: ICustomRequest, res: Response) => {
  const { path, parentPath } = req.body;

  const uploadPath = `${sanitizeParentPath(parentPath, req.user.id)}/${path}`;

  const responseSignedURL = await mediaService.getSignedUrlForPublicUpload({
    path: uploadPath,
  });

  return res.status(200).json({ data: responseSignedURL });
};

export const createMediaData = async (req: ICustomRequest, res: Response) => {
  const { file, path, bucket, mimeType, provider, format, ...rest } = req.body;

  const uploadPath = `${req.user.id}/${path}`;
  const data = await mediaService.create({
    file,
    path: uploadPath,
    bucket,
    provider,
    mimeType,
    options: {
      uploader: req.user.id,
      ...rest,
    },
  });

  return res.status(201).json({ data });
};

export const deleteFile = async (req: ICustomRequest, res: Response) => {
  const mediaId = asString(req.params.mediaId);
  if (!mediaId) throw new NotFoundError('Media not found');
  const existingMedia = await mediaService.delete(mediaId);

  if (isEmpty(existingMedia)) throw new NotFoundError('Media not found');

  return res.status(200).json({ data: existingMedia });
};

export const getMediaById = async (req: ICustomRequest, res: Response) => {
  const mediaId = asString(req.params.mediaId);
  if (!mediaId) throw new BadRequestError('Media not found');
  const data = await mediaService.getById(mediaId);

  if (isEmpty(data)) throw new NotFoundError('Media not found');

  return res.status(200).json({ data: toMediaPublic(data!) });
};

export const getMediaPublicUrl = async (req: ICustomRequest, res: Response) => {
  const { path, bucket, provider } = req.body;
  const signedUrl = await mediaService.getPublicUrl(path, bucket, provider);
  if (isEmpty(signedUrl)) throw new NotFoundError('Media not found at path');

  return res.status(200).json({ data: signedUrl });
};

export const updateMedia = async (req: ICustomRequest, res: Response) => {
  const mediaId = asString(req.params.mediaId);
  if (!mediaId) throw new NotFoundError('Media not found');
  const existingMedia = await mediaService.getById(mediaId);

  const updateData = pick(req.body, ['caption', 'access', 'metadata', 'thumbnail', 'name']);

  if (isEmpty(existingMedia)) throw new NotFoundError('Media not found');

  const data = await mediaService.update(mediaId, updateData);

  return res.status(200).json({ data });
};

export const getMediaPublicUrls = async (req: ICustomRequest, res: Response) => {
  const ids = asString(req.query.ids);
  if (!ids) throw new NotFoundError('Media(s) not found at path');
  const signedUrls = await mediaService.getMediaByIds(ids.split(','));
  if (isEmpty(signedUrls)) throw new NotFoundError('Media(s) not found at path');

  const data = Object.fromEntries(Object.entries(signedUrls).map(([id, media]) => [id, toMediaPublic(media)]));

  return res.status(200).json({ data });
};

export const onUploadComplete = async (req: ICustomRequest, res: Response) => {
  const { id, mediaId, context, secure_url, public_id, asset_id, eventId, eager, resource_type } = req.body;

  const queuedId = id || mediaId;
  if (queuedId) {
    const media = await mediaService.getById(queuedId);
    if (!media) throw new NotFoundError('Media not found');
    if (media.mimeType?.startsWith('video')) {
      await addVideoJob(media.id, eventId);
    }
    return res.status(200).json({ data: { queued: true } });
  }

  const { custom: { rid } = {} } = context || {};

  if (!rid) throw new BadRequestError(`Missing context id`);

  const isImage = resource_type === 'image' || !resource_type?.startsWith('video');
  const eagerVariants = isImage && Array.isArray(eager) && eager.length >= 6 ? parseImageEagerResults(eager) : {};

  const updatedMedia = await mediaService.update(rid, {
    url: public_id,
    metadata: { publicUrl: secure_url, asset_id },
    ...eagerVariants,
  });

  logger.debug(`Updated media ${updatedMedia.id}`);

  return res.status(200).json({ data: { updated: true } });
};
