import type { Job } from 'pg-boss';
import { spawn } from 'child_process';
import crypto from 'crypto';
import fs from 'fs/promises';
import os from 'os';
import axios from 'axios';
import MediaService from '@/features/media/service';
import { MEDIA_PUBLIC_BUCKET_NAME, VIDEO_THUMBNAIL_SIZES } from '@/features/media/constants';
import { EMediaProvider } from '../definitions/enums';
import logger from '../logger';
import { BaseQueue, type QueueConfig } from './base';

export const VIDEO_QUEUE_NAME = 'video-processing';

export interface IVideoJobPayload {
  mediaId: string;
  eventId: string;
}

const mediaService = new MediaService();

const convertToWebP = async (inputPath: string, outputPath: string, size: number, fps = 10): Promise<Buffer> => {
  return new Promise((resolve, reject) => {
    const ffmpeg = spawn('ffmpeg', [
      '-i',
      inputPath,
      '-vf',
      `scale=${size}:-1,fps=${fps}`,
      '-pix_fmt',
      'yuv420p',
      '-loop',
      '0',
      '-f',
      'webp',
      outputPath,
    ]);

    ffmpeg.stderr.on('data', (data) => logger.debug(`ffmpeg stderr: ${data}`));
    ffmpeg.on('close', async (code) => {
      if (code !== 0) {
        // clean up partial output file on failure
        await fs.unlink(outputPath).catch(() => {});
        return reject(new Error(`FFmpeg exited with ${code}`));
      }
      try {
        const result = await fs.readFile(outputPath);
        await fs.unlink(outputPath);
        resolve(result);
      } catch (e) {
        reject(e);
      }
    });
  });
};

class VideoQueue extends BaseQueue<IVideoJobPayload> {
  readonly name = VIDEO_QUEUE_NAME;

  protected get queueConfig(): QueueConfig {
    return {
      retryLimit: 3,
      retryDelay: 60,
      retryBackoff: true,
      // transcoding a large video can outlast the 15m default
      expireInSeconds: 1800,
    };
  }

  protected async handle({ mediaId, eventId }: IVideoJobPayload, _job: Job<IVideoJobPayload>) {
    const tempPath = `${os.tmpdir()}/${crypto.randomUUID()}.tmp`;
    let tempWritten = false;

    try {
      const media = await mediaService.getById(mediaId);
      if (!media) return;

      const { signedUrl } = await mediaService.getPublicUrl(media.url, media.storage.bucket, media.provider, {
        download: true,
      });

      const res = await axios.get(signedUrl, { responseType: 'arraybuffer' });
      if (!res.status || !res.data) throw new Error('Failed to fetch media stream');
      const buffer = Buffer.from(res.data);

      await fs.writeFile(tempPath, buffer);
      tempWritten = true;

      const sizes = VIDEO_THUMBNAIL_SIZES;
      const thumbBuffers: Record<string, Buffer> = {};

      for (const [suffix, size] of Object.entries(sizes)) {
        const outPath = `${os.tmpdir()}/${crypto.randomUUID()}.webp`;
        try {
          const output = await convertToWebP(tempPath, outPath, size);
          if (output.length) {
            thumbBuffers[suffix] = output;
          }
        } catch (err) {
          logger.warn('WebP conversion failed', { suffix, err });
        }
      }

      await fs.unlink(tempPath);
      tempWritten = false;

      const thumbEntries = Object.entries(thumbBuffers);

      if (thumbEntries.length === 0) {
        logger.error('No thumbnails generated', { mediaId, eventId });
        throw new Error('No thumbnails generated');
      }

      const uploaded = await Promise.all(
        thumbEntries.map(([suffix, thumbBuffer]) =>
          mediaService.uploadFile({
            bucket: MEDIA_PUBLIC_BUCKET_NAME,
            path: `${eventId}/${mediaId}${suffix}.webp`,
            file: thumbBuffer.toString('base64'),
            mimeType: 'image/webp',
            provider: EMediaProvider.Supabase,
            options: {},
          }),
        ),
      );

      const mappedThumbs = thumbEntries.reduce(
        (acc, [suffix], i) => {
          acc[suffix] = uploaded[i];
          return acc;
        },
        {} as Record<string, any>,
      );

      await mediaService.update(mediaId, {
        thumbnail: '@/2x' in mappedThumbs ? mappedThumbs['@/2x'].path : Object.values(mappedThumbs)[0]?.path,
        metadata: {
          ...(media.metadata || {}),
          thumbnails: mappedThumbs,
          eventId,
        },
      });

      logger.info('Video worker completed', { mediaId, eventId });
    } catch (err) {
      logger.error('Video worker error', { mediaId, eventId, err });
      if (tempWritten) await fs.unlink(tempPath).catch(() => {});
      throw err;
    }
  }
}

export const videoQueue = new VideoQueue();

export const addVideoJob = (mediaId: string, eventId: string) => videoQueue.publish({ mediaId, eventId });
