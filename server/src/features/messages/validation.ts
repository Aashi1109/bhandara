import { validateSchema } from '@/src/common/helpers';
import { MESSAGE_TABLE_NAME } from './constants';

const dynamicMediaSchema = {
  type: 'array',
  minItems: 1,
  items: {
    type: 'string',
    format: 'uuid',
    errorMessage: 'Should must be a valid UUID',
  },
  uniqueItems: true,
  errorMessage: 'Must be an array of unique UUIDs',
};

const messageContentSchema = {
  oneOf: [
    {
      type: 'string',
      errorMessage: 'Message text must be a valid string',
    },
    {
      type: 'object',
      properties: {
        text: { type: 'string', errorMessage: 'Text must be a valid string' },
      },
      required: ['text'],
      additionalProperties: false,
      errorMessage: "Plain text message must have a 'text' field",
    },
    {
      // Rich object message
      type: 'object',
      properties: {
        text: {
          type: ['string', 'null'],
          errorMessage: 'Text must be a string or null',
        },
        media: dynamicMediaSchema,
      },
      required: ['media'],
      additionalProperties: false,
      errorMessage: 'Rich object message must have valid fields',
    },
  ],
  errorMessage: 'Message content must be either plain text or a rich object',
};

const messageSchema = {
  type: 'object',
  properties: {
    userId: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'userId must be a valid UUID',
    },
    parentId: {
      type: ['string', 'null'],
      format: 'uuid',
      errorMessage: 'parentId must be a valid UUID or null',
    },
    content: messageContentSchema,
    isEdited: {
      type: 'boolean',
      errorMessage: 'isEdited must be a boolean value',
    },
    threadId: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'threadId must be a valid UUID',
    },
  },
  required: ['userId', 'content', 'isEdited', 'threadId'],
  additionalProperties: false,
  errorMessage: {
    type: 'Message data must be an object',
    required: {
      userId: 'userId is required and must be a valid UUID',
      content: 'Message content is required',
      isEdited: 'isEdited is required',
    },
  },
};
const updateSchema = {
  type: 'object',
  properties: {
    content: messageContentSchema,
  },
  additionalProperties: false,
  errorMessage: {
    type: 'Message data must be an object',
  },
};

const validateMessageCreate = validateSchema(`${MESSAGE_TABLE_NAME}_CREATE`, messageSchema);

const validateMessageUpdate = validateSchema(`${MESSAGE_TABLE_NAME}_UPDATE`, updateSchema);

export { validateMessageCreate, validateMessageUpdate, messageSchema, updateSchema as messageUpdateSchema };
