import { validateSchema } from '@/common/helpers';
import { TAG_TABLE_NAME } from './constants';

const tagSchema = {
  type: 'object',
  properties: {
    name: { type: 'string', errorMessage: 'Name must be a valid string' },
    value: { type: 'string', errorMessage: 'Value must be a valid string' },
    description: {
      type: ['string', 'null'],
      errorMessage: 'Description must be a string or null',
    },
    icon: {
      type: ['string', 'null'],
      errorMessage: 'Icon must be a string or null',
    },
    color: {
      type: ['string', 'null'],
      errorMessage: 'Color must be a string or null',
    },
    parentId: {
      type: ['string', 'null'],
      format: 'uuid',
      errorMessage: 'Parent ID must be a valid UUID or null',
    },
    createdBy: {
      type: ['string', 'null'],
      format: 'uuid',
      errorMessage: 'Created by must be a valid UUID or null',
    },
  },
  required: ['name', 'value'],
  additionalProperties: false,
  errorMessage: {
    type: 'Tag data must be an object',
    required: {
      name: 'Name is required',
      value: 'Value is required',
    },
  },
};

const updateSchema = {
  type: 'object',
  properties: {
    icon: {
      type: ['string', 'null'],
      errorMessage: 'Icon must be a string or null',
    },
    color: {
      type: ['string', 'null'],
      errorMessage: 'Color must be a string or null',
    },
    parentId: {
      type: ['string', 'null'],
      format: 'uuid',
      errorMessage: 'Parent ID must be a valid UUID or null',
    },
  },
  additionalProperties: false,
  errorMessage: {
    type: 'Tag data must be an object',
  },
};

const validateTagCreate = validateSchema(`${TAG_TABLE_NAME}_CREATE`, tagSchema);
const validateTagUpdate = validateSchema(`${TAG_TABLE_NAME}_UPDATE`, updateSchema);

export { validateTagCreate, validateTagUpdate, tagSchema, updateSchema as tagUpdateSchema };
