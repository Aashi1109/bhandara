export const MEDIA_TABLE_NAME = "Media";
export const MEDIA_EVENT_JUNCTION_TABLE_NAME = "EventMedia";
export const MEDIA_PROFILES_BUCKET_NAME = "avatars";
export const MEDIA_FILE_BUCKET_NAME = "event-files";
export const MEDIA_PUBLIC_BUCKET_NAME = "public";

export const MEDIA_BUCKET_CONFIG = {
  [MEDIA_FILE_BUCKET_NAME]: {
    accept: ["image/*", "video/*"],
    maxSize: 1024 * 1024 * 20, // 20MB
  },
  [MEDIA_PROFILES_BUCKET_NAME]: {
    accept: ["image/*"],
    maxSize: 1024 * 1024 * 2, // 2MB
  },
  [MEDIA_PUBLIC_BUCKET_NAME]: {
    accept: ["image/*"],
    maxSize: 1024 * 1024 * 20, // 20MB
  },
};
