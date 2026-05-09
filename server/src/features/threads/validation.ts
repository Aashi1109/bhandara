import { validateSchema } from '@/common/helpers';
import { EAccessLevel } from '@/common/definitions/enums';
import { THREAD_TABLE_NAME } from './constants';

const lockHistoryItemSchema = {
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
};

const threadSchema = {
  type: 'object',
  properties: {
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
      default: EAccessLevel.Public,
    },
    lockHistory: {
      type: 'array',
      items: lockHistoryItemSchema,
      errorMessage: 'Lock history must be an array of lock entries',
    },
  },
  required: ['createdBy', 'visibility'],
  additionalProperties: false,
  errorMessage: {
    type: 'Thread data must be an object',
    required: {
      createdBy: 'Creator is required',
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
      oneOf: [{ type: 'array', items: lockHistoryItemSchema }, { type: 'null' }],
      errorMessage: 'Lock history must be an array or null',
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
