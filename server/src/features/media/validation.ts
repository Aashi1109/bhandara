import { validateSchema } from '@/helpers';
import { MEDIA_BUCKET_CONFIG, MEDIA_TABLE_NAME } from './constants';
const mediaStorageSchema = {
  type: 'object',
  properties: {
    provider: {
      type: 'string',
      enum: ['local', 's3', 'gcs', 'cloudinary', 'supabase'],
      errorMessage: "Provider must be one of 'local', 's3', 'gcs', 'cloudinary', or 'supabase'",
    },
    path: { type: 'string', errorMessage: 'Path must be a valid string' },
    metadata: {
      type: 'object',
      additionalProperties: true,
      errorMessage: 'Metadata must be an object',
    },
  },
  required: ['provider', 'path', 'metadata'],
  additionalProperties: false,
  errorMessage: {
    type: 'Media storage data must be an object',
    required: {
      provider: 'Provider is required',
      path: 'Path is required',
      metadata: 'Metadata is required',
    },
  },
};

const mediaSchema = {
  type: 'object',
  properties: {
    provider: {
      type: 'string',
      enum: ['local', 's3', 'gcs', 'cloudinary', 'supabase'],
      errorMessage: "Provider must be one of 'local', 's3', 'gcs', 'cloudinary', or 'supabase'",
    },
    path: {
      type: 'string',
      errorMessage: 'Upload path must be a valid string',
    },
    bucket: {
      type: 'string',
      enum: Object.keys(MEDIA_BUCKET_CONFIG),
      errorMessage: 'Bucket must be a valid string',
    },
    mimeType: {
      type: ['string', 'null'],
      errorMessage: 'MIME type must be a string or null',
    },
    options: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          enum: ['image', 'video', 'audio', 'document'],
          errorMessage: "Type must be one of 'image', 'video', 'audio', or 'document'",
        },
        caption: {
          type: ['string', 'null'],
          errorMessage: 'Caption must be a string or null',
        },
        thumbnail: {
          type: ['string', 'null'],
          errorMessage: 'Thumbnail must be a string or null',
        },
        duration: {
          type: ['integer', 'null'],
          minimum: 0,
          errorMessage: 'Duration must be a non-negative integer or null',
        },
        uploader: {
          type: 'string',
          format: 'uuid',
          errorMessage: 'Uploader must be a valid UUID',
        },
        access: {
          type: 'string',
          enum: ['public', 'private', 'restricted'],
          errorMessage: "Access level must be one of 'public', 'private', or 'restricted'",
        },
        name: {
          type: ['string', 'null'],
          errorMessage: 'Name must be a string or null',
        },
        metadata: {
          type: ['object', 'null'],
          additionalProperties: true,
          errorMessage: 'Metadata must be an object or null',
        },
        size: {
          type: 'integer',
          minimum: 0,
          errorMessage: 'Size must be a non-negative integer',
        },
        format: {
          type: 'string',
          errorMessage: 'Format must be a string or null',
        },
      },
      required: ['type', 'uploader', 'size', 'format'],
      additionalProperties: false,
      errorMessage: {
        required: {
          type: 'Media type is required',
          size: 'Media size is required',
          uploader: 'Media uploader is required',
          access: 'Media access is required',
        },
      },
    },
  },
  required: ['provider', 'path', 'bucket', 'mimeType', 'options'],
  additionalProperties: false,
  errorMessage: {
    type: 'Media data must be an object',
    required: {
      provider: 'Provider is required',
      path: 'Path is required',
      bucket: 'Bucket is required',
      mimeType: 'MIME type is required',
      options: 'Options are required',
    },
  },
};

const updateSchema = {
  type: 'object',
  properties: {
    caption: {
      type: ['string', 'null'],
      errorMessage: 'Caption must be a string or null',
    },
    thumbnail: {
      type: ['string', 'null'],
      errorMessage: 'Thumbnail must be a string or null',
    },
    mimeType: {
      type: ['string', 'null'],
      errorMessage: 'MIME type must be a string or null',
    },
    access: {
      type: 'string',
      enum: ['public', 'private', 'restricted'],
      errorMessage: "Access level must be one of 'public', 'private', or 'restricted'",
    },
    metadata: {
      type: 'object',
      additionalProperties: true,
      errorMessage: 'Metadata must be an object',
    },
    name: {
      type: ['string', 'null'],
      errorMessage: 'Name must be a string or null',
    },
    url: {
      type: ['string', 'null'],
      errorMessage: 'URL must be a string or null',
    },
  },
  additionalProperties: false,
  errorMessage: {
    type: 'Media data must be an object',
  },
};

const validateMediaCreate = validateSchema(`${MEDIA_TABLE_NAME}_CREATE`, mediaSchema);

const validateMediaUpdate = validateSchema(`${MEDIA_TABLE_NAME}_UPDATE`, updateSchema);

export { validateMediaCreate, validateMediaUpdate, mediaSchema, updateSchema as mediaUpdateSchema, mediaStorageSchema };
