import { validateSchema } from '@/helpers/validation';

const loginSchema = {
  type: 'object',
  properties: {
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
    password: { type: 'string', minLength: 6, errorMessage: 'Password must be at least 6 characters long' },
  },
  required: ['email', 'password'],
  additionalProperties: false,
};

const signupSchema = {
  type: 'object',
  properties: {
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
    password: { type: 'string', minLength: 6, errorMessage: 'Password must be at least 6 characters long' },
    name: { type: 'string', minLength: 2, errorMessage: 'Name is required (min 2 characters)' },
    location: { type: 'object', additionalProperties: true },
    gender: { type: ['string', 'null'], enum: ['male', 'female', 'other'], errorMessage: 'Valid gender is required' },
  },
  required: ['email', 'password', 'name'],
  additionalProperties: false,
};

export const validateLogin = validateSchema('AUTH_LOGIN', loginSchema);
export const validateSignup = validateSchema('AUTH_SIGNUP', signupSchema);

export const schemas = {
  login: loginSchema,
  signup: signupSchema,
};
