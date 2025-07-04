import { EVENT_MEDIA_BUCKET } from "@/constants/global";
import {
  getMediaPublicURLs,
  IPickerAsset,
  uploadPickerAsset,
  getPublicUploadSignedURL,
  updateMedia,
} from "../api/media.action";
import { isEmpty } from "@/utils";
import { EMediaType } from "@/definitions/enums";
import { IMedia } from "@/definitions/types";
import {
  generateImageVariants,
  generateVideoThumbnails,
} from "@/utils/compression";

export interface IAttachedFile extends Omit<IPickerAsset, "uri"> {
  error?: string;
  uploadedRatio?: number;
  retryCallback?: () => void;
  uploadResult?: IMedia;
  isDeleting?: boolean;
  publicURL?: IMedia["publicUrl"];
  uri?: string;
}

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

    if (type === EMediaType.VIDEO) {
      generateVideoThumbnails(uri)
        .then(async (thumbs) => {
          await Promise.all(
            thumbs.map(async (t) => {
              const signed = await getPublicUploadSignedURL(
                `${baseName}${t.suffix}.jpg`,
                opts.pPath
              );
              await axios.put(signed.signedUrl, t.blob, {
                headers: { "Content-Type": t.blob.type },
              });
            })
          );
          await updateMedia(result.id, {
            thumbnail: `${opts.pPath}/${baseName}@2x.jpg`,
          });
        })
        .catch((err) => console.error(err));
    }

    if (type === EMediaType.IMAGE) {
      generateImageVariants(uri, mimeType)
        .then(async (variants) => {
          await Promise.all(
            variants.map(async (v) => {
              const signed = await getPublicUploadSignedURL(
                `${baseName}${v.suffix}.jpg`,
                opts.pPath
              );
              await axios.put(signed.signedUrl, v.blob, {
                headers: { "Content-Type": v.blob.type },
              });
            })
          );
        })
        .catch((err) => console.error(err));
    }

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

  for (const _file of files) {
    const { name = "", size } = _file;

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
    promises.push(
      uploadFile(_file, setAttachedFiles, opts).catch((error) => {
        // Individual file errors are already handled in uploadFile function
        // Just return null to continue with other uploads
        return null;
      })
    );
  }

  // Wait for all uploads to complete
  const results = await Promise.allSettled(promises);
  const successCountFiles = results.filter((result) => result.status === "fulfilled").map((result) => result.value);

  const successCount = successCountFiles.length;

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
  return { successCount, errorCount: promises.length - successCount };
};
