import { describe, expect, it } from 'vitest';
import { decryptRecordFields, decryptValue, encryptRecordFields, encryptValue, hashForLookup } from '@/src/common/utils';

describe('encryption utils', () => {
  it('round-trips encrypted strings', () => {
    const encrypted = encryptValue('user@example.com');

    expect(encrypted).toContain('enc:v1:');
    expect(encrypted).not.toBe('user@example.com');
    expect(decryptValue(encrypted)).toBe('user@example.com');
  });

  it('produces deterministic lookup hashes', () => {
    expect(hashForLookup('user@example.com')).toBe(hashForLookup('user@example.com'));
    expect(hashForLookup('user@example.com')).not.toBe(hashForLookup('other@example.com'));
  });

  it('decrypts configured fields on raw rows', () => {
    const encryptedRow = encryptRecordFields(
      {
        __sid: 'supabase-user-1',
        email: 'user@example.com',
        name: 'Test User',
      },
      ['email', '__sid'],
    );

    const row = decryptRecordFields(encryptedRow, ['email', '__sid']);

    expect(row).toEqual({
      __sid: 'supabase-user-1',
      email: 'user@example.com',
      name: 'Test User',
    });
  });
});
