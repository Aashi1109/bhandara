import { validateSchema } from '@/helpers';
import { EAccessLevel, EThreadType } from '@/definitions/enums';
import { THREAD_TABLE_NAME } from './constants';
const threadSchema = {
  type: 'object',
  properties: {
    type: {
      type: 'string',
      enum: Object.values(EThreadType),
      errorMessage: `Type must be either ${Object.values(EThreadType).join(',')}`,
    },
    createdBy: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'Creator is required',
    },
    eventId: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'Event ID is required',
    },
    visibility: {
      type: 'string',
      enum: Object.values(EAccessLevel),
      errorMessage: `Visibility must be one of ${Object.values(EAccessLevel).join(',')}`,
    },
    lockHistory: {
      type: 'object',
      properties: {
        lockedBy: {
          type: 'string',
          format: 'uuid',
          errorMessage: 'LockedBy must be a valid UUID',
        },
        lockedAt: {
          type: 'string',
          format: 'date-time',
          errorMessage: 'LockedAt must be a valid date-time',
        },
      },
      required: ['lockedBy', 'lockedAt'],
      additionalProperties: false,
      errorMessage: "Each lock event must have 'lockedBy' and 'lockedAt'",
    },
  },
  required: ['type', 'createdBy', 'visibility'],
  additionalProperties: false,
  errorMessage: {
    type: 'Thread data must be an object',
    required: {
      type: 'Type is required',
      status: 'Status is required',
      visibility: 'Visibility is required',
    },
  },
};

const updateSchema = {
  type: 'object',
  properties: {
    visibility: {
      type: 'string',
      enum: Object.values(EAccessLevel),
      errorMessage: `Visibility must be one of ${Object.values(EAccessLevel).join(',')}`,
    },
    lockHistory: {
      type: ['object', 'null'],
      properties: {
        lockedBy: {
          type: 'string',
          format: 'uuid',
          errorMessage: 'LockedBy must be a valid UUID',
        },
        lockedAt: {
          type: 'string',
          format: 'date-time',
          errorMessage: 'LockedAt must be a valid date-time',
        },
      },
      required: ['lockedBy', 'lockedAt'],
      additionalProperties: false,
      errorMessage: "Each lock event must have 'lockedBy' and 'lockedAt'",
    },
  },
  additionalProperties: false,
  errorMessage: {
    type: 'Thread data must be an object',
  },
};

const validateThreadCreate = validateSchema(`${THREAD_TABLE_NAME}_CREATE`, threadSchema);

const validateThreadUpdate = validateSchema(`${THREAD_TABLE_NAME}_UPDATE`, updateSchema);

export { validateThreadCreate, validateThreadUpdate, threadSchema, updateSchema as threadUpdateSchema };
