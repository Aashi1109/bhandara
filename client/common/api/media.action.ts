import { Platform } from "react-native";
import axiosClient from "./base";
import { base64ToBlob, uriToBlob, compressFile } from "@/utils";
import axios from "axios";
import type { IBaseResponse, IMedia } from "@/definitions/types";
import type { EMediaType } from "@/definitions/enums";

export interface IPickerAsset {
  uri: string;
  mimeType: string | null;
  size: number;
  type: EMediaType;
  name: string;
}

function getFileFormat(fileName: string): string {
  const parts = fileName.split(".");
  if (parts.length < 2) return "unknown";
  return parts.pop()!.toLowerCase();
}

export const uploadPickerAsset = async (
  asset: IPickerAsset,
  options: { bucket: string; compressionPercentage: number; onProgress?: (progress: number) => void } & Record<
    string,
    any
  >
) => {
  const { bucket, compressionPercentage, onProgress, customName, parentPath, ...rest } = options;

  const { uri, mimeType, name, size: fileSize, type } = asset;
  const fileFormat = getFileFormat(name);

  const parsedName = (customName || name).replace(`.${fileFormat}`, "");

  onProgress?.(10);
  let progress = 10;
  const mockProgressInterval = setInterval(() => {
    onProgress?.(++progress);
  }, 500);
  const compressed = await compressFile(uri, { mimeType: mimeType || undefined, percentage: compressionPercentage });
  clearInterval(mockProgressInterval);

  onProgress?.(Math.max(progress, 30));
  const newSize = compressed.size ?? fileSize;

  const response = await axiosClient.post("/media/get-signed-upload-url", {
    path: name,
    bucket,
    mimeType,
    size: newSize,
    name: parsedName,
    type,
    parentPath,
    format: fileFormat,
    ...rest
  });

  const { data } = response.data;
  const { row, signedUrl } = data;

  const isWebPlatform = Platform.OS === "web";
  let file: Blob | null = null;
  if (isWebPlatform) {
    file = compressed.blob ?? base64ToBlob(compressed.uri);
  } else {
    file = await uriToBlob(compressed.uri);
  }

  const uploadResponse = await axios.put(signedUrl, file, {
    headers: {
      "Content-Type": file.type
    },
    onUploadProgress: (progressEvent) => {
      if (progressEvent.total) {
        const percentCompleted = Math.max(0.3, Math.round((progressEvent.loaded * 100) / progressEvent.total));
        onProgress?.(percentCompleted);
      }
    }
  });

  if (uploadResponse.status !== 200) {
    throw new Error("Failed to upload file");
  }

  return { ...row, size: newSize };
};

export const deleteMedia = async (mediaId: string) => {
  const response = await axiosClient.delete(`/media/${mediaId}`);
  return response.data;
};

export const getMediaPublicURLs = async (mediaIds: string[]): Promise<IBaseResponse<Record<string, IMedia>>> => {
  const queryParams = new URLSearchParams({
    ids: mediaIds.join(",")
  });

  const response = await axiosClient.get(`/media/public-urls?${queryParams.toString()}`);
  return response.data;
};

export const getPublicUploadSignedURL = async (path: string, parentPath?: string) => {
  const response = await axiosClient.post("/media/get-public-upload-url", {
    path,
    parentPath
  });
  return response.data.data;
};

export const updateMedia = async (id: string, data: Partial<IMedia>): Promise<IBaseResponse<IMedia>> => {
  const response = await axiosClient.patch(`/media/${id}`, data);
  return response.data;
};
