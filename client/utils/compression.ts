import { Platform } from "react-native";

let workerClientPromise: Promise<{
  runWorker: <T>(action: string, payload: any) => Promise<T>;
} | null> | null = null;

async function getWorkerClient() {
  if (Platform.OS !== "web") return null;
  if (!workerClientPromise) {
    workerClientPromise = import("../workers/client").catch(() => null);
  }
  return workerClientPromise;
}

/**
 * Compress a video blob in the browser to roughly the target size.
 */
async function compressVideoWeb(blob: Blob, targetSize: number): Promise<Blob> {
  const url = URL.createObjectURL(blob);
  const video = document.createElement("video");
  video.src = url;
  video.muted = true;
  await new Promise((res) => video.addEventListener("loadedmetadata", res, { once: true }));
  const bitsPerSecond = video.duration ? (targetSize * 8) / video.duration : undefined;
  const stream = (video as any).captureStream();
  const chunks: BlobPart[] = [];
  const recorder = new MediaRecorder(stream, { mimeType: "video/webm", videoBitsPerSecond: bitsPerSecond });
  recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  const stopPromise = new Promise<Blob>((resolve) => {
    recorder.onstop = () => resolve(new Blob(chunks, { type: "video/webm" }));
  });
  recorder.start();
  video.play();
  await new Promise((res) => video.addEventListener("ended", res, { once: true }));
  recorder.stop();
  const result = await stopPromise;
  URL.revokeObjectURL(url);
  return result;
}

export interface CompressResult {
  uri: string;
  blob?: Blob;
  size?: number;
}

export interface CompressOptions {
  mimeType?: string;
  percentage?: number; // desired size percentage of original file
  width?: number;
  height?: number;
}

/**
 * Compress an image or video file according to the provided options.
 */
export async function compressFile(uri: string, options: CompressOptions = {}): Promise<CompressResult> {
  const { mimeType, percentage = 100, width, height } = options;
  const isImage = mimeType?.startsWith("image");
  const isVideo = mimeType?.startsWith("video");
  if (!isImage && !isVideo) {
    const blob = Platform.OS === "web" ? await fetch(uri).then((r) => r.blob()) : undefined;
    return { uri, blob, size: blob?.size };
  }

  if (isImage) {
    if (Platform.OS === "web") {
      const worker = await getWorkerClient();
      if (worker) {
        const res = await worker.runWorker<CompressResult>('compressImage', {
          uri,
          width: width || height,
          percentage,
        });
        return res;
      }
      const { default: imageCompression } = await require("browser-image-compression");
      const blob = await fetch(uri).then((r) => r.blob());
      const maxSizeMB = (blob.size / 1024 / 1024) * (percentage / 100);
      const compressed = await imageCompression(blob, {
        maxSizeMB,
        maxWidthOrHeight: width || height || 1280,
        useWebWorker: true,
      });
      return {
        uri: URL.createObjectURL(compressed),
        blob: compressed,
        size: compressed.size,
      };
    } else {
      const { Image } = await require("react-native-compressor" as any);
      const compressedUri: string = await Image.compress(uri, {
        compressionMethod: "auto",
        quality: percentage,
        maxWidth: width,
        maxHeight: height
      });
      try {
        const b = await fetch(compressedUri).then((r) => r.blob());
        return { uri: compressedUri, size: b.size };
      } catch {
        return { uri: compressedUri };
      }
    }
  }

  if (isVideo) {
    if (Platform.OS === "web") {
      const blob = await fetch(uri).then((r) => r.blob());
      const target = blob.size * (percentage / 100);
      const compressed = await compressVideoWeb(blob, target);
      return { uri: URL.createObjectURL(compressed), blob: compressed, size: compressed.size };
    }

    const { Video } = await require("react-native-compressor" as any);
    const compressedUri: string = await Video.compress(uri, {
      compressionMethod: "auto",
      quality: percentage
    });
    try {
      const b = await fetch(compressedUri).then((r) => r.blob());
      return { uri: compressedUri, size: b.size };
    } catch {
      return { uri: compressedUri };
    }
  }

  return { uri };
}

export interface VariantResult extends CompressResult {
  suffix: string;
}

export async function generateVideoThumbnails(uri: string): Promise<VariantResult[]> {
  const { default: VideoThumbnails } = await require("expo-video-thumbnails");
  const base = await VideoThumbnails.getThumbnailAsync(uri, { time: 1000 });
  if (Platform.OS === "web") {
    const worker = await getWorkerClient();
    if (worker) {
      const small = await worker.runWorker<CompressResult>('compressImage', { uri: base.uri, width: 260 });
      const medium = await worker.runWorker<CompressResult>('compressImage', { uri: base.uri, width: 480 });
      const large = await worker.runWorker<CompressResult>('compressImage', { uri: base.uri });
      const results = [
        { ...small, suffix: "@1x" },
        { ...medium, suffix: "@2x" },
        { ...large, suffix: "@3x" },
      ];
      return results as VariantResult[];
    }
  }

  const small = await compressFile(base.uri, { mimeType: "image/jpeg", width: 260 });
  const medium = await compressFile(base.uri, { mimeType: "image/jpeg", width: 480 });
  const large = await compressFile(base.uri, { mimeType: "image/jpeg" });

  const results = [
    { ...small, suffix: "@1x" },
    { ...medium, suffix: "@2x" },
    { ...large, suffix: "@3x" },
  ];

  for (const r of results) {
    if (!r.blob) {
      r.blob = await fetch(r.uri).then((resp) => resp.blob());
    }
  }

  return results;
}

export async function generateImageVariants(
  uri: string,
  mimeType: string | null
): Promise<VariantResult[]> {
  if (Platform.OS === "web") {
    const worker = await getWorkerClient();
    if (worker) {
      const res = await worker.runWorker<VariantResult[]>("imageVariants", { uri, mimeType });
      return res;
    }
  }

  const low = await compressFile(uri, { mimeType: mimeType || undefined, width: 400 });
  const high = await compressFile(uri, { mimeType: mimeType || undefined, width: 800 });

  const results = [
    { ...low, suffix: "@1x" },
    { ...high, suffix: "@2x" },
  ];

  for (const r of results) {
    if (!r.blob) {
      r.blob = await fetch(r.uri).then((resp) => resp.blob());
    }
  }

  return results;
}
