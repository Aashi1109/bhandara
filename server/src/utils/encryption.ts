import crypto from 'crypto';
import { type Model, DataTypes } from 'sequelize';
import config from '@/config';
import logger from '@/logger';

const ENCRYPTION_PREFIX = 'enc:v1';
const IV_LENGTH = 12;

const deriveKey = (secret: string) => crypto.createHash('sha256').update(secret, 'utf8').digest();

const encryptionKey = deriveKey(config.encryption.dataKey);
const hashKey = deriveKey(config.encryption.hashKey);

const toBase64Url = (value: Buffer) => value.toString('base64url');
const fromBase64Url = (value: string) => Buffer.from(value, 'base64url');

export const encryptValue = (value: string | null | undefined): string | null | undefined => {
  if (value === null || value === undefined) {
    return value;
  }

  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
  const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return `${ENCRYPTION_PREFIX}:${toBase64Url(iv)}:${toBase64Url(authTag)}:${toBase64Url(encrypted)}`;
};

export const decryptValue = (value: string | null | undefined): string | null | undefined => {
  if (value === null || value === undefined) {
    return value;
  }

  const parts = value.split(':');
  if (parts.length !== 5 || parts[0] !== 'enc' || parts[1] !== 'v1') {
    throw new Error('Malformed encrypted payload');
  }

  const [, , ivPart, authTagPart, payloadPart] = parts;

  if (!ivPart || !authTagPart || !payloadPart) {
    throw new Error('Malformed encrypted payload');
  }

  const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey, fromBase64Url(ivPart), {
    authTagLength: 16,
  });
  decipher.setAuthTag(fromBase64Url(authTagPart));

  const decrypted = Buffer.concat([decipher.update(fromBase64Url(payloadPart)), decipher.final()]);
  return decrypted.toString('utf8');
};

export const hashForLookup = (value: string | null | undefined): string | null => {
  if (value === null || value === undefined) {
    return null;
  }

  return crypto.createHmac('sha256', hashKey).update(value, 'utf8').digest('hex');
};

export const hashForCacheKey = (value: string | null | undefined, bytes: number = 12): string | null => {
  if (value === null || value === undefined) {
    return null;
  }

  return crypto.createHmac('sha256', hashKey).update(value, 'utf8').digest().subarray(0, bytes).toString('base64url');
};

export const encryptRecordFields = <T extends Record<string, any>>(row: T, fields: readonly string[]): T => {
  const clone = { ...row };

  for (const field of fields) {
    const currentValue = clone[field];
    if (typeof currentValue === 'string') {
      clone[field as keyof T] = encryptValue(currentValue) as T[keyof T];
    }
  }

  return clone;
};

export const decryptRecordFields = <T extends Record<string, any>>(row: T, fields: readonly string[]): T => {
  const clone = { ...row };

  for (const field of fields) {
    const currentValue = clone[field];
    if (typeof currentValue === 'string') {
      try {
        clone[field as keyof T] = decryptValue(currentValue) as T[keyof T];
      } catch (error) {
        logger.error(`Failed to decrypt ${field}: ${error}`);
        throw error;
      }
    }
  }

  return clone;
};

export const decryptRecordFieldList = <T extends Record<string, any>>(rows: T[], fields: readonly string[]): T[] => {
  return rows.map((row) => decryptRecordFields(row, fields));
};

export const encryptedTextAttribute = (
  fieldName: string,
  {
    allowNull = true,
    lookupHashField,
    ...rest
  }: {
    allowNull?: boolean;
    lookupHashField?: string;
    defaultValue?: unknown;
  } & Record<string, unknown> = {},
) => {
  return {
    ...rest,
    allowNull,
    type: DataTypes.TEXT,
    get(this: Model) {
      const rawValue = this.getDataValue(fieldName) as string | null;
      return decryptValue(rawValue);
    },
    set(this: Model, value: unknown) {
      if (value === null || value === undefined) {
        this.setDataValue(fieldName, value as null);
        if (lookupHashField) {
          this.setDataValue(lookupHashField, null);
        }
        return;
      }

      if (typeof value !== 'string') {
        throw new TypeError(`${fieldName} must be a string`);
      }

      this.setDataValue(fieldName, encryptValue(value) as string);
      if (lookupHashField) {
        this.setDataValue(lookupHashField, hashForLookup(value));
      }
    },
  };
};
