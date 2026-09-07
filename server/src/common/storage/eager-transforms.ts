import type { IMediaThumbnails } from './types';

// Cloudinary eager transform arrays — used by server-side uploads.
export const IMAGE_EAGER = [
  // thumbnails: square crops for list/grid/strip views
  { width: 128, height: 128, crop: 'fill', quality: 'auto', fetch_format: 'auto' },
  { width: 256, height: 256, crop: 'fill', quality: 'auto', fetch_format: 'auto' },
  { width: 512, height: 512, crop: 'fill', quality: 'auto', fetch_format: 'auto' },
  // variants: aspect-maintained at multiple widths for full display
  { width: 400, quality: 'auto', fetch_format: 'auto' },
  { width: 800, quality: 'auto', fetch_format: 'auto' },
  { width: 1600, quality: 'auto', fetch_format: 'auto' },
];

export const VIDEO_EAGER = [
  // HLS adaptive stream (index 0)
  { streaming_profile: 'auto', format: 'm3u8' },
  // sm: square crop for the 64px thumbnail strip
  { width: 128, height: 128, crop: 'fill', format: 'jpg', start_offset: '1' },
  // md/xl: aspect-ratio maintained for cards and poster frames
  { width: 480, format: 'jpg', start_offset: '1' },
  { width: 960, format: 'jpg', start_offset: '1' },
];

// Pre-built Cloudinary transformation strings for signed upload params.
// Kept in sync with the arrays above — update both together.
export const IMAGE_EAGER_STRING =
  'w_128,h_128,c_fill,q_auto,f_auto|w_256,h_256,c_fill,q_auto,f_auto|w_512,h_512,c_fill,q_auto,f_auto|w_400,q_auto,f_auto|w_800,q_auto,f_auto|w_1600,q_auto,f_auto';

// Videos use async eager processing (HLS can take minutes).
// The server handles them via the video job queue instead of blocking the upload response.
export const VIDEO_EAGER_STRING = null;

// Parse eager results from a Cloudinary upload response (server-side or client callback).
// Input: array of objects each containing a `secure_url` string.
export function parseImageEagerResults(eager: Array<{ secure_url: string }>): {
  thumbnails: IMediaThumbnails;
  variants: IMediaThumbnails;
} {
  const urls = eager.map((e) => e.secure_url ?? '');
  return {
    thumbnails: { sm: urls[0] ?? '', md: urls[1] ?? '', xl: urls[2] ?? '' },
    variants: { sm: urls[3] ?? '', md: urls[4] ?? '', xl: urls[5] ?? '' },
  };
}

export function parseVideoEagerResults(eager: Array<{ secure_url: string }>): {
  streamUrl: string;
  thumbnails: IMediaThumbnails;
} {
  const urls = eager.map((e) => e.secure_url ?? '');
  return {
    streamUrl: urls[0] ?? '',
    thumbnails: { sm: urls[1] ?? '', md: urls[2] ?? '', xl: urls[3] ?? '' },
  };
}
