import { ICustomRequest } from "@/definitions/types";
import { Response } from "express";
import MediaService from "./service";
import { BadRequestError, NotFoundError } from "@/exceptions";
import { isEmpty, pick } from "@/utils";
import { EMediaProvider } from "@/definitions/enums";
import logger from "@/logger";
import { addVideoJob } from "@/queues/video";

const mediaService = new MediaService();

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

export const getSignedUploadUrl = async (
  req: ICustomRequest,
  res: Response
) => {
  let { path, bucket, mimeType, provider, parentPath, format, ...rest } =
    req.body;
  provider ??= EMediaProvider.Supabase;

  const uploadPath = `${parentPath || req.user.id}/${path}`;
  const insertData = {
    path: uploadPath,
    bucket,
    provider,
    mimeType,
    options: {
      uploader: req.user.id,
      ...rest,
      format,
    },
  };

  const responseSignedURL = await mediaService.getSignedUrlForUpload(
    insertData
  );

  return res.status(200).json({ data: responseSignedURL });
};

export const getPublicSignedUploadUrl = async (
  req: ICustomRequest,
  res: Response
) => {
  const { path, parentPath } = req.body;

  const uploadPath = `${parentPath || req.user.id}/${path}`;

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
  const { mediaId } = req.params;
  const existingMedia = await mediaService.delete(mediaId);

  if (isEmpty(existingMedia)) throw new NotFoundError("Media not found");

  return res.status(200).json(existingMedia);
};

export const getMediaById = async (req: ICustomRequest, res: Response) => {
  const { mediaId } = req.params;
  const data = await mediaService.getById(mediaId);

  if (isEmpty(data)) throw new NotFoundError("Media not found");

  return res.status(200).json({ data });
};

export const getMediaPublicUrl = async (req: ICustomRequest, res: Response) => {
  const { path, bucket, provider } = req.body;
  const signedUrl = await mediaService.getPublicUrl(path, bucket, provider);
  if (isEmpty(signedUrl)) throw new NotFoundError("Media not found at path");

  return res.status(200).json(signedUrl);
};

export const updateMedia = async (req: ICustomRequest, res: Response) => {
  const { mediaId } = req.params;
  const existingMedia = await mediaService.getById(mediaId);

  const updateData = pick(req.body, [
    "caption",
    "access",
    "metadata",
    "thumbnail",
    "name",
  ]);

  if (isEmpty(existingMedia)) throw new NotFoundError("Media not found");

  const data = await mediaService.update(mediaId, updateData);

  return res.status(200).json({ data });
};

export const getMediaPublicUrls = async (
  req: ICustomRequest,
  res: Response
) => {
  const { ids } = req.query;
  const signedUrls = await mediaService.getMediaByIds(
    (ids as string).split(",")
  );
  if (isEmpty(signedUrls))
    throw new NotFoundError("Media(s) not found at path");

  return res.status(200).json({ data: signedUrls });
};

export const onUploadComplete = async (req: ICustomRequest, res: Response) => {
  const { id, mediaId, context, secure_url, public_id, asset_id, eventId } =
    req.body;

  const queuedId = id || mediaId;
  if (queuedId) {
    const media = await mediaService.getById(queuedId);
    if (!media) throw new NotFoundError("Media not found");
    if (media.mimeType?.startsWith("video")) {
      await addVideoJob(media.id, eventId);
    }
    return res.status(200).json({ queued: true });
  }

  const { custom: { rid } = {} } = context || {};

  if (!rid) throw new BadRequestError(`Missing context id`);

  const updatedMedia = await mediaService.update(rid, {
    url: public_id,
    metadata: { publicUrl: secure_url, asset_id },
  });

  logger.debug(`Updated media ${updatedMedia.id}`);

  return res.status(200).json({ success: true });
};
