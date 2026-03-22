import { validateSchema } from '@/helpers';
import { EVENT_TABLE_NAME } from './constants';
import { EEventParticipantStatus, EEventStatus, EEventType } from '@/definitions/enums';
import { validateEventTimings } from './status';

const locationSchema = {
  type: 'object',
  properties: {
    address: { type: 'string', errorMessage: 'Address must be a valid string' },
  },
  required: ['address'],
  additionalProperties: true,
  errorMessage: {
    type: 'Location data must be an object',
    required: {
      address: 'Address is required',
    },
  },
};

// Event Participant Schema
const participantSchema = {
  type: 'object',
  properties: {
    user: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'userId must be a valid UUID',
    },
    status: {
      type: 'string',
      enum: Object.values(EEventParticipantStatus),
      errorMessage: `Status must be one of ${Object.values(EEventParticipantStatus).join(', ')}`,
    },
  },
  required: ['user', 'status'],
  additionalProperties: false,
  errorMessage: {
    type: 'Participant data must be an object',
    required: {
      userId: 'userId is required and must be a valid UUID',
      status: 'Status is required',
    },
  },
};

const verifierSchema = {
  type: 'object',
  properties: {
    user: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'Each verifier must be a valid UUID',
    },
    verifiedAt: {
      type: 'string',
      format: 'date-time',
      errorMessage: 'Verified at must be a valid date-time',
    },
  },
  required: ['user', 'verifiedAt'],
};

const eventSchema = {
  type: 'object',
  properties: {
    id: {
      type: ['string', 'null'],
      format: 'uuid',
    },
    name: { type: 'string', errorMessage: 'Name must be a valid string' },
    description: {
      type: 'string',
      errorMessage: 'Description must be a valid string',
    },
    location: locationSchema,
    // participants: {
    //   type: "array",
    //   items: participantSchema,
    //   uniqueItems: true,
    //   errorMessage: "Participants must be an array of unique objects",
    // },
    // verifiers: {
    //   type: ["array", null],
    //   items: verifierSchema,
    //   uniqueItems: true,
    //   errorMessage: "Verifiers must be an array of unique objects",
    // },
    timings: {
      type: 'object',
      properties: {
        start: {
          type: 'string',
          format: 'date-time',
          errorMessage: 'Start time must be a valid date-time',
        },
        end: {
          type: 'string',
          format: 'date-time',
          errorMessage: 'End time must be a valid date-time',
        },
      },
      required: ['end', 'start'],
      errorMessage: {
        type: 'Timings must be an object',
        required: {
          start: 'Start time is required',
          end: 'End time is required',
        },
      },
    },
    type: {
      type: 'string',
      enum: Object.values(EEventType),
      errorMessage: `Type must be one of ${Object.values(EEventType).join(', ')}`,
    },
    createdBy: {
      type: 'string',
      format: 'uuid',
      errorMessage: 'createdBy must be a valid UUID',
    },
    status: {
      type: 'string',
      enum: Object.values(EEventStatus),
      errorMessage: `Status must be one of ${Object.values(EEventStatus).join(', ')}`,
    },
    capacity: {
      type: ['integer', 'null'],
      minimum: 50,
      errorMessage: 'Capacity must be a non-negative integer',
    },
    media: {
      type: ['array', 'null'],
      items: { type: 'string', format: 'uuid' },
      uniqueItems: true,
    },
    tags: {
      type: ['array'],
      items: { type: 'string', format: 'uuid' },
      minItems: 1,
      uniqueItems: true,
    },
  },
  required: ['name', 'description', 'location', 'timings', 'type', 'createdBy', 'tags'],

  additionalProperties: false,
  errorMessage: {
    type: 'Event data must be an object',
    required: {
      name: 'Name is required',
      description: 'Description is required',
      location: 'Location is required',
      type: 'Type is required',
      createdBy: 'createdBy is required',
      capacity: 'Capacity is required',
    },
  },
};

const eventUpdateSchema = {
  type: 'object',
  properties: {
    name: { type: 'string', errorMessage: 'Name must be a valid string' },
    description: {
      type: 'string',
      errorMessage: 'Description must be a valid string',
    },
    location: { oneOf: [locationSchema, { type: 'null' }] },
    participants: {
      oneOf: [
        {
          type: 'array',
          items: participantSchema,
          uniqueItems: true,
          errorMessage: 'Participants must be an array of unique objects',
        },
        { type: 'null' },
      ],
    },
    verifiers: {
      oneOf: [
        {
          type: 'array',
          items: verifierSchema,
          uniqueItems: true,
          errorMessage: 'Verifiers must be an array of unique objects',
        },
        { type: 'null' },
      ],
    },
    status: {
      type: 'string',
      enum: [EEventStatus.Cancelled],
      errorMessage: `Status must be ${EEventStatus.Cancelled}`,
    },
    capacity: {
      type: 'integer',
      minimum: 0,
      errorMessage: 'Capacity must be a non-negative integer',
    },
    timings: {
      type: 'object',
      properties: {
        start: {
          type: 'string',
          format: 'date-time',
          errorMessage: 'Start time must be a valid date-time',
        },
        end: {
          type: 'string',
          format: 'date-time',
          errorMessage: 'End time must be a valid date-time',
        },
      },
      required: ['start', 'end'],
      errorMessage: {
        type: 'Timings must be an object',
        required: {
          start: 'Start time is required',
          end: 'End time is required',
        },
      },
    },
  },
};

const validateEventCreate = validateSchema(`${EVENT_TABLE_NAME}_CREATE`, eventSchema);

// Enhanced validation function that includes timing validation
const validateEventCreateWithTiming = <T extends { timings?: { start: string | Date; end: string | Date } }, R>(
  data: T,
  callback: (validData: T) => R,
): R => {
  // First run the schema validation
  const result = validateEventCreate(data, (validData) => {
    // Add custom timing validation
    if (validData.timings) {
      validateEventTimings(validData.timings);
    }
    return callback(validData);
  });

  return result;
};

const validateEventUpdateBase = validateSchema(`${EVENT_TABLE_NAME}_UPDATE`, eventUpdateSchema);

const validateEventUpdate = <
  T extends {
    timings?: { start: string | Date; end: string | Date };
    status?: string;
  },
  R,
>(
  data: T,
  callback: (validData: T) => R,
): R =>
  validateEventUpdateBase(data, (validData) => {
    if (validData.timings && validData.status !== EEventStatus.Cancelled) {
      validateEventTimings(validData.timings);
    }
    return callback(validData);
  });

export { validateEventCreateWithTiming as validateEventCreate, validateEventUpdate, eventSchema, eventUpdateSchema };
