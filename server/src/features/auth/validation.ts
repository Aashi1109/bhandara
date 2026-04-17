import { validateSchema } from '@/helpers/validation';

const loginSchema = {
  type: 'object',
  properties: {
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
    password: {
      type: 'string',
      minLength: 8,
      maxLength: 128,
      errorMessage: 'Password must be at least 8 characters long',
    },
  },
  required: ['email', 'password'],
  additionalProperties: false,
};

const signupSchema = {
  type: 'object',
  properties: {
    email: { type: 'string', format: 'email', errorMessage: 'Valid email is required' },
    password: {
      type: 'string',
      minLength: 8,
      maxLength: 128,
      errorMessage: 'Password must be at least 8 characters long',
    },
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
      maxLength: 128,
      errorMessage: 'Password must be at least 8 characters',
    },
  },
  required: ['token', 'email', 'password'],
  additionalProperties: false,
};

const signInWithIdTokenSchema = {
  type: 'object',
  properties: {
    token: { type: 'string', minLength: 1, maxLength: 4096 },
    code: { type: 'string', minLength: 1, maxLength: 4096 },
    codeVerifier: { type: 'string', minLength: 1, maxLength: 4096 },
    redirectUri: { type: 'string', format: 'uri', maxLength: 2048 },
  },
  additionalProperties: false,
};

export const validateLogin = validateSchema('AUTH_LOGIN', loginSchema);
export const validateSignup = validateSchema('AUTH_SIGNUP', signupSchema);
export const validateSignInWithIdToken = validateSchema('AUTH_SIGN_IN_WITH_ID_TOKEN', signInWithIdTokenSchema);
export const validateForgotPassword = validateSchema('AUTH_FORGOT_PASSWORD', forgotPasswordSchema);
export const validateVerifyOTP = validateSchema('AUTH_VERIFY_OTP', verifyOTPSchema);
export const validateResetPassword = validateSchema('AUTH_RESET_PASSWORD', resetPasswordSchema);

export const schemas = {
  login: loginSchema,
  signup: signupSchema,
  forgotPassword: forgotPasswordSchema,
  verifyOTP: verifyOTPSchema,
  resetPassword: resetPasswordSchema,
  signInWithIdToken: signInWithIdTokenSchema,
};
