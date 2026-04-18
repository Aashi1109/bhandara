import { beforeEach, describe, expect, it } from 'vitest';
import { cacheKeys } from '@/src/features/cache/keys';
import { storeResetToken, consumeResetToken } from '@/src/features/auth/otp-helpers';
import { getUserSessionCache, setUserSessionCache, updateUserSessionCache } from '@/src/features/users/helpers';
import { defaultSession, mockRedis } from '../mocks/external';

describe('session and reset-token secret storage', () => {
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

  it('stores encrypted session tokens and decrypts them on read', async () => {
    await setUserSessionCache({
      data: defaultSession,
      sessionId: 'session-1',
      userId: 'user-1',
    });

    const rawPayload = storage.get('session:session-1');
    expect(rawPayload).toContain('enc:v1:');
    expect(rawPayload).not.toContain(defaultSession.accessToken);
    expect(rawPayload).not.toContain(defaultSession.refreshToken);

    const hydrated = await getUserSessionCache('session-1');
    expect(hydrated).toEqual(defaultSession);
  });

  it('re-encrypts rotated session secrets during updates', async () => {
    await updateUserSessionCache('session-1', {
      ...defaultSession,
      accessToken: 'rotated-access-token',
      refreshToken: 'rotated-refresh-token',
    });

    const rawPayload = storage.get('session:session-1');
    expect(rawPayload).toContain('enc:v1:');
    expect(rawPayload).not.toContain('rotated-access-token');
    expect(rawPayload).not.toContain('rotated-refresh-token');

    const hydrated = await getUserSessionCache('session-1');
    expect(hydrated?.accessToken).toBe('rotated-access-token');
    expect(hydrated?.refreshToken).toBe('rotated-refresh-token');
  });

  it('stores encrypted password reset token payloads', async () => {
    await storeResetToken('reset-token', 'user@example.com');

    const rawPayload = storage.get(`pwd_token:${cacheKeys.passwordResetToken('reset-token')}`);
    expect(rawPayload).toContain('enc:v1:');
    expect(rawPayload).not.toContain('user@example.com');

    await expect(consumeResetToken('reset-token')).resolves.toBe('user@example.com');
    expect(storage.has(`pwd_token:${cacheKeys.passwordResetToken('reset-token')}`)).toBe(false);
  });
});
