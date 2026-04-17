import crypto from 'crypto';
import { RedisCache } from '@/features/cache';
import { REDIS_CONNECTION_NAMES, PASSWORD_RESET_CONFIG } from '@/constants';

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

export const generateOTP = (): string => {
  return String(crypto.randomInt(100_000, 999_999));
};

export const storeOTP = (email: string, otp: string): Promise<unknown> => {
  const record: OTPRecord = { otp, attempts: 0 };
  return otpCache.setItem(email, record, PASSWORD_RESET_CONFIG.otpTtl);
};

export const verifyOTP = async (email: string, otp: string): Promise<{ valid: boolean; reason?: string }> => {
  const record = await otpCache.getItem<OTPRecord>(email);

  if (!record) {
    return { valid: false, reason: 'Code expired or not found. Please request a new one.' };
  }

  if (record.attempts >= PASSWORD_RESET_CONFIG.maxAttempts) {
    await otpCache.deleteItem(email);
    return { valid: false, reason: 'Too many incorrect attempts. Please request a new code.' };
  }

  if (record.otp !== otp) {
    await otpCache.updateValue(email, { ...record, attempts: record.attempts + 1 });
    const remaining = PASSWORD_RESET_CONFIG.maxAttempts - record.attempts - 1;
    return { valid: false, reason: `Incorrect code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.` };
  }

  await otpCache.deleteItem(email);
  return { valid: true };
};

export const storeResetToken = (token: string, email: string): Promise<unknown> => {
  return tokenCache.setItem(token, { email }, PASSWORD_RESET_CONFIG.tokenTtl);
};

export const consumeResetToken = async (token: string): Promise<string | null> => {
  const record = await tokenCache.getItem<{ email: string }>(token);
  if (!record) return null;
  await tokenCache.deleteItem(token);
  return record.email;
};

export const generateResetToken = (): string => {
  return crypto.randomBytes(32).toString('hex');
};
