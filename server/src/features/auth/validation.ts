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

const forgotPasswordSchema = {
  type: 'object',
  properties: {
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
  },
  required: ['email'],
  additionalProperties: false,
};

const verifyOTPSchema = {
  type: 'object',
  properties: {
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
    code: {
      type: 'string',
      pattern: '^[0-9]{6}$',
      errorMessage: '6-digit verification code is required',
    },
  },
  required: ['email', 'code'],
  additionalProperties: false,
};

const resetPasswordSchema = {
  type: 'object',
  properties: {
    token: { type: 'string', minLength: 1, errorMessage: 'Reset token is required' },
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
    password: {
      type: 'string',
      minLength: 8,
      errorMessage: 'Password must be at least 8 characters',
    },
  },
  required: ['token', 'email', 'password'],
  additionalProperties: false,
};

export const validateLogin = validateSchema('AUTH_LOGIN', loginSchema);
export const validateSignup = validateSchema('AUTH_SIGNUP', signupSchema);

export const schemas = {
  login: loginSchema,
  signup: signupSchema,
  forgotPassword: forgotPasswordSchema,
  verifyOTP: verifyOTPSchema,
  resetPassword: resetPasswordSchema,
};
