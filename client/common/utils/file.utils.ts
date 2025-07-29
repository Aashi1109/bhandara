import { getMediaPublicURLs, IPickerAsset, uploadPickerAsset, getPublicUploadSignedURL } from "../api/media.action";
import axiosClient from "../api/base";

import { isEmpty } from "@/utils";
import { EMediaType } from "@/definitions/enums";
import { IMedia } from "@/definitions/types";
import { generateImageVariants } from "@/utils/compression";
import axios from "axios";
import { MEDIA_BUCKET_CONFIG } from "@/constants/media";

export interface IAttachedFile extends Omit<IPickerAsset, "uri"> {
  error?: string;
  uploadedRatio?: number;
  retryCallback?: () => void;
  uploadResult?: IMedia;
  isDeleting?: boolean;
  publicURL?: IMedia["publicUrl"];
  uri?: string;
}

export const validateFileSize = (bucket: string, size?: number) => {
  if (!size) throw new Error("File is corrupt or empty");
  const config = MEDIA_BUCKET_CONFIG[bucket];
  if (!config) throw new Error("Invalid bucket");
  if (size > config.maxSize) throw new Error("File size exceeds bucket limit");
};

export const uploadFile = async (
  file: IPickerAsset,
  setAttachedFiles: React.Dispatch<React.SetStateAction<IAttachedFile[]>>,
  opts: { bucket: string; pPath: string }
) => {
  const { uri, mimeType = "", name = "", size = 0 } = file;
  const type = (mimeType?.split("/")[0] || "") as EMediaType;

  // Create a retryCallback function
  const retryCallback = () => {
    // Remove error and reset upload percentage
    setAttachedFiles((prev) =>
      prev.map((f) => {
        if (f.name === name) {
          return { ...f, error: undefined, uploadedRatio: 0 };
        }
        return f;
      })
    );

    // Try uploading again
    uploadFile(file, setAttachedFiles, opts);
  };

  const handleProgress = (progress: number) => {
    setAttachedFiles((prev) =>
      prev.map((f) => {
        if (f.name === name) {
          f.uploadedRatio = progress;
        }
        return f;
      })
    );
  };

  try {
    // Update UI that compression is starting
    setAttachedFiles((prev) =>
      prev.map((f) => {
        if (f.name === name) {
          return { ...f, uploadedRatio: 10, error: undefined };
        }
        return f;
      })
    );

    // Call the upload function with progress tracking
    const result = await uploadPickerAsset(
      {
        name,
        type,
        mimeType,
        uri,
        size: size
      },
      {
        bucket: opts.bucket,
        compressionPercentage: 70,
        parentPath: opts.pPath,
        onProgress: handleProgress
      }
    );

    const baseName = result.url.split("/").pop() || "";

    if (type === EMediaType.Image) {
      generateImageVariants(uri, mimeType)
        .then(async (variants) => {
          await Promise.all(
            variants.map(async (v) => {
              const signed = await getPublicUploadSignedURL(`${baseName}${v.suffix}.jpg`, opts.pPath);
              await axios.put(signed.signedUrl, v.blob, {
                headers: { "Content-Type": v.blob?.type }
              });
            })
          );
        })
        .catch((err) => console.error(err));
    }
    axiosClient.post("/webhooks/on-upload-complete", { id: result.id, eventId: opts.pPath }).catch(() => {});

    // Update with 100% when complete
    setAttachedFiles((prev) =>
      prev.map((f) => {
        if (f.name === name) {
          return { ...f, uploadedRatio: 100, uploadResult: result };
        }
        return f;
      })
    );

    return result;
  } catch (error: any) {
    console.error("error", error);
    // Update the file with error state and add retry callback
    setAttachedFiles((prev) =>
      prev.map((f) => {
        if (f.name === name) {
          return { ...f, error: error?.message || "Upload failed", retryCallback };
        }
        return f;
      })
    );

    throw error; // Re-throw to be caught by the main handler
  }
};

type HandleFilePickProps = {
  opts: { bucket: string; pPath: string };
  setAttachedFiles: React.Dispatch<React.SetStateAction<IAttachedFile[]>>;
  files: Array<any>;
};

export const processPickedFiles = async ({
  files,
  setAttachedFiles,
  opts
}: HandleFilePickProps): Promise<{ successCount: number; errorCount: number }> => {
  const promises = [];
  const errorMessages: Array<string> = [];
  const successCountFiles: Array<IMedia> = [];

  for (const _file of files) {
    const { name = "", size } = _file;
    try {
      validateFileSize(opts.bucket, size);
    } catch (error: any) {
      errorMessages.push(error?.message || "Something went wrong");
      continue;
    }

    // Add file to state first
    setAttachedFiles((prev) => [
      ...prev,
      {
        ..._file,
        name,
        type: (_file.mimeType?.split("/")[0] || "") as EMediaType,
        mimeType: _file.mimeType || "",
        uri: _file.uri,
        size: size || 0,
        uploadedRatio: 0
      }
    ]);

    // Process files in parallel but handle errors individually
    promises.push(uploadFile(_file, setAttachedFiles, opts));
  }

  // Wait for all uploads to complete
  const results = await Promise.allSettled(promises);
  results.forEach((result) => {
    if (result.status === "fulfilled") {
      successCountFiles.push(result.value);
    } else {
      errorMessages.push(result.reason?.message || "Something went wrong");
    }
  });

  const successCount = successCountFiles.length;
  const errorCount = errorMessages.length;

  const publicIdsFetch = successCountFiles.map((result) => result?.id);
  publicIdsFetch.length &&
    getMediaPublicURLs(publicIdsFetch)
      .then((res) => {
        const publicURLs = res.data;
        if (isEmpty(publicURLs)) return;

        setAttachedFiles((prev) => {
          return prev.map((f) => {
            if (f.uploadResult?.id) {
              const publicURL = publicURLs?.[f.uploadResult.id]?.publicUrl;
              if (publicURL) {
                f.uploadResult = publicURLs[f.uploadResult.id];
              }
            }
            return f;
          });
        });
      })
      .catch((error) => {
        console.error("error", error);
      });
  return { successCount, errorCount };
};
