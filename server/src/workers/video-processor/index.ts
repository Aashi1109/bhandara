import { Job, Worker } from "bullmq";
import { VIDEO_QUEUE_NAME } from "@/queues/video";
import MediaService from "@/features/media/service";
import logger from "@/logger";
import { spawn } from "child_process";
import { MEDIA_PUBLIC_BUCKET_NAME } from "@/features/media/constants";
import { EMediaProvider } from "@/definitions/enums";
import crypto from "crypto";
import fs from "fs/promises";
import axios from "axios";
import { WORKER_CONNECTION_CONFIG } from "@/config";

const mediaService = new MediaService();

const convertToWebP = async (
  inputPath: string,
  outputPath: string,
  size: number,
  fps = 10
): Promise<Buffer> => {
  return new Promise((resolve, reject) => {
    const ffmpeg = spawn("ffmpeg", [
      "-i",
      inputPath,
      "-vf",
      `scale=${size}:-1,fps=${fps}`,
      "-pix_fmt",
      "yuv420p",
      "-loop",
      "0",
      "-f",
      "webp",
      outputPath,
    ]);

    ffmpeg.stderr.on("data", (data) => console.error(`ffmpeg stderr: ${data}`));
    ffmpeg.on("close", async (code) => {
      if (code !== 0) return reject(new Error(`FFmpeg exited with ${code}`));
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

export const processor = async (job: Job) => {
  const { mediaId, eventId } = job.data as { mediaId: string; eventId: string };
  try {
    const media = await mediaService.getById(mediaId);
    if (!media) return;

    const { signedUrl } = await mediaService.getPublicUrl(
      media.url,
      media.storage.bucket,
      media.storage.provider,
      { download: true }
    );

    const res = await axios.get(signedUrl, { responseType: "arraybuffer" });
    if (!res.status || !res.data)
      throw new Error("Failed to fetch media stream");
    const buffer = Buffer.from(res.data);

    const tempPath = `./tmp/${crypto.randomUUID()}.${media.metadata?.format}`;
    await fs.writeFile(tempPath, buffer);

    const sizes = { "@/1x": 160, "@/2x": 320, "@/3x": 480 };
    const thumbBuffers: Record<string, Buffer> = {};

    for (const [suffix, size] of Object.entries(sizes)) {
      const outPath = `/tmp/${crypto.randomUUID()}.webp`;
      try {
        const output = await convertToWebP(tempPath, outPath, size);
        if (output.length) {
          thumbBuffers[suffix] = output;
        }
      } catch (err) {
        console.error("WebP conversion failed", { suffix, err });
        delete sizes[suffix];
      }
    }

    await fs.unlink(tempPath);

    const uploaded = await Promise.all(
      Object.entries(thumbBuffers).map(([suffix, buffer]) =>
        mediaService.uploadFile({
          bucket: MEDIA_PUBLIC_BUCKET_NAME,
          path: `${eventId}/${mediaId}${suffix}.webp`,
          file: buffer.toString("base64"),
          mimeType: "image/webp",
          provider: EMediaProvider.Supabase,
          options: {},
        })
      )
    );

    const mappedThumbs = Object.keys(sizes).reduce((acc, suffix, i) => {
      acc[suffix] = uploaded[i];
      return acc;
    }, {} as Record<string, any>);

    if (Object.keys(mappedThumbs).length === 0) {
      logger.error("No thumbnails generated", { mediaId, eventId });
      return true;
    }

    await mediaService.update(mediaId, {
      thumbnail:
        "@/2x" in mappedThumbs
          ? mappedThumbs["@/2x"].path
          : Object.values(mappedThumbs)[0]?.path,
      metadata: {
        ...(media.metadata || {}),
        thumbnails: mappedThumbs,
        eventId,
      },
    });

    logger.info("Video worker completed", { mediaId, eventId });
    return true;
  } catch (err) {
    logger.error("Video worker error", { mediaId, eventId, err });
    return false;
  }
};

export default new Worker(VIDEO_QUEUE_NAME, processor, {
  connection: WORKER_CONNECTION_CONFIG,
});
