import crypto from 'crypto';
import { RedisCache } from '@/src/features/cache';
import { cacheKeys } from '@/src/features/cache/keys';
import { REDIS_CONNECTION_NAMES, PASSWORD_RESET_CONFIG } from '@/src/common/constants';
import { decryptRecordFields, encryptRecordFields } from '@/src/common/utils';

const otpCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Cache,
  namespace: PASSWORD_RESET_CONFIG.otpNamespace,
  defaultTTLSeconds: PASSWORD_RESET_CONFIG.otpTtl,
});

const tokenCache = new RedisCache({
  connectionName: REDIS_CONNECTION_NAMES.Cache,
  namespace: PASSWORD_RESET_CONFIG.tokenNamespace,
  defaultTTLSeconds: PASSWORD_RESET_CONFIG.tokenTtl,
});

interface OTPRecord {
  otp: string;
  attempts: number;
}

const OTP_ENCRYPTED_FIELDS = ['otp'] as const;
const RESET_TOKEN_ENCRYPTED_FIELDS = ['email'] as const;

export const generateOTP = (): string => {
  return String(crypto.randomInt(100_000, 999_999));
};

export const storeOTP = (email: string, otp: string): Promise<unknown> => {
  const record: OTPRecord = { otp, attempts: 0 };
  return otpCache.setItem(cacheKeys.passwordResetOtp(email), encryptRecordFields(record, OTP_ENCRYPTED_FIELDS));
};

export const verifyOTP = async (email: string, otp: string): Promise<{ valid: boolean; reason?: string }> => {
  const storedRecord = await otpCache.getItem<OTPRecord>(cacheKeys.passwordResetOtp(email));
  const record = storedRecord ? decryptRecordFields(storedRecord, OTP_ENCRYPTED_FIELDS) : null;

  if (!record) {
    return { valid: false, reason: 'Code expired or not found. Please request a new one.' };
  }

  if (record.attempts >= PASSWORD_RESET_CONFIG.maxAttempts) {
    await otpCache.deleteItem(cacheKeys.passwordResetOtp(email));
    return { valid: false, reason: 'Too many incorrect attempts. Please request a new code.' };
  }

  if (record.otp !== otp) {
    await otpCache.updateValue(
      cacheKeys.passwordResetOtp(email),
      encryptRecordFields({ ...record, attempts: record.attempts + 1 }, OTP_ENCRYPTED_FIELDS),
    );
    const remaining = PASSWORD_RESET_CONFIG.maxAttempts - record.attempts - 1;
    return { valid: false, reason: `Incorrect code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.` };
  }

  await otpCache.deleteItem(cacheKeys.passwordResetOtp(email));
  return { valid: true };
};

export const storeResetToken = (token: string, email: string): Promise<unknown> => {
  return tokenCache.setItem(
    cacheKeys.passwordResetToken(token),
    encryptRecordFields({ email }, RESET_TOKEN_ENCRYPTED_FIELDS),
    PASSWORD_RESET_CONFIG.tokenTtl,
  );
};

export const consumeResetToken = async (token: string): Promise<string | null> => {
  const key = cacheKeys.passwordResetToken(token);
  const record = await tokenCache.getItem<{ email: string }>(key);
  if (!record) return null;
  await tokenCache.deleteItem(key);
  return decryptRecordFields(record, RESET_TOKEN_ENCRYPTED_FIELDS).email ?? null;
};

export const generateResetToken = (): string => {
  return crypto.randomBytes(32).toString('hex');
};
