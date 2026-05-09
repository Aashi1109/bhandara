import { beforeEach, describe, expect, it } from 'vitest';
import {
  getUserCacheByEmail,
  getUserCacheByUsername,
  setUserCache,
  setUserCacheByEmail,
  setUserCacheByUsername,
} from '@/features/users/helpers';
import { consumeResetToken, storeOTP, storeResetToken, verifyOTP } from '@/features/auth/otp-helpers';
import { defaultUser, mockRedis } from '../mocks/external';

describe('cache privacy', () => {
  const storage = new Map<string, string>();

  beforeEach(() => {
    storage.clear();

    mockRedis.set.mockImplementation(async (key: string, value: string) => {
      storage.set(key, value);
      return 'OK';
    });
    mockRedis.get.mockImplementation(async (key: string) => {
      return storage.get(key) ?? null;
    });
    mockRedis.del.mockImplementation(async (...keys: string[]) => {
      keys.forEach((key) => storage.delete(key));
      return keys.length;
    });
  });

  it('keeps raw email and username out of user cache keys while preserving lookups', async () => {
    await setUserCache(defaultUser.id, defaultUser as any);
    await setUserCacheByEmail(defaultUser.email, defaultUser as any);
    await setUserCacheByUsername(defaultUser.username!, defaultUser as any);

    const rawUserPayload = storage.get(`users:${defaultUser.id}`);
    expect(rawUserPayload).toContain('enc:v1:');
    expect(rawUserPayload).not.toContain(defaultUser.email);

    const cacheKeys = [...storage.keys()];
    expect(cacheKeys.some((key) => key.includes(defaultUser.email))).toBe(false);
    expect(cacheKeys.some((key) => key.includes(defaultUser.username!))).toBe(false);

    await expect(getUserCacheByEmail(defaultUser.email)).resolves.toMatchObject(defaultUser);
    await expect(getUserCacheByUsername(defaultUser.username!)).resolves.toMatchObject(defaultUser);
  });

  it('keeps password-reset identifiers and codes out of Redis keys and payloads', async () => {
    await storeOTP(defaultUser.email, '123456');

    const otpEntry = [...storage.entries()].find(([key]) => key.startsWith('pwd_otp:'));
    expect(otpEntry).toBeDefined();
    expect(otpEntry?.[0]).not.toContain(defaultUser.email);
    expect(otpEntry?.[1]).toContain('enc:v1:');
    expect(otpEntry?.[1]).not.toContain('123456');
    await expect(verifyOTP(defaultUser.email, '123456')).resolves.toEqual({ valid: true });

    await storeResetToken('reset-token', defaultUser.email);

    const tokenEntry = [...storage.entries()].find(([key]) => key.startsWith('pwd_token:'));
    expect(tokenEntry).toBeDefined();
    expect(tokenEntry?.[0]).not.toContain('reset-token');
    expect(tokenEntry?.[1]).toContain('enc:v1:');
    expect(tokenEntry?.[1]).not.toContain(defaultUser.email);
    await expect(consumeResetToken('reset-token')).resolves.toBe(defaultUser.email);
  });
});
