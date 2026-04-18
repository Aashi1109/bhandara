import { getDBConnection } from '@/src/common/connections/db';
import { DataTypes, Model } from 'sequelize';
import { getUUIDv7 } from '@/src/common/helpers';
import { USER_TABLE_NAME } from './constants';
import type { IBaseUser } from '@/src/common/definitions/types';
import { decryptRecordFields, encryptedTextAttribute } from '@/src/common/utils';

const sequelize = getDBConnection()!;
type UserAttributes = Omit<IBaseUser, 'createdAt' | 'updatedAt' | 'address' | 'media' | 'profilePic'> & {
  emailLookupHash: string | null;
  profilePic: Record<string, any> | null;
};

export const USER_ENCRYPTED_FIELDS = ['email', '__sid'] as const;
export const decryptUserRow = <T extends Record<string, any>>(row: T) =>
  decryptRecordFields(row, USER_ENCRYPTED_FIELDS);
export const decryptUserRows = <T extends Record<string, any>>(rows: T[]) => rows.map((row) => decryptUserRow(row));

export class User extends Model<UserAttributes, UserAttributes> {
  declare id: string;
  declare name: string;
  declare email: string;
  declare __sid: string | null;
  declare emailLookupHash: string | null;
  declare gender: string;
  declare isVerified: boolean;
  declare profilePic: Record<string, any> | null;
  declare mediaId: string | null;
  declare bio: string | null;
  declare username?: string;
  declare password: string | null;
  declare meta: Record<string, any>;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare media?: any;
}

User.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    name: { type: DataTypes.TEXT, allowNull: false },
    email: encryptedTextAttribute('email', {
      allowNull: false,
      lookupHashField: 'emailLookupHash',
    }),
    emailLookupHash: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    __sid: encryptedTextAttribute('__sid', {
      allowNull: true,
    }),
    gender: { type: DataTypes.TEXT, allowNull: false },
    isVerified: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    profilePic: { type: DataTypes.JSONB },
    mediaId: {
      type: DataTypes.UUID,
    },
    bio: { type: DataTypes.TEXT, allowNull: true },
    username: { type: DataTypes.TEXT },
    password: { type: DataTypes.TEXT },
    meta: { type: DataTypes.JSONB, defaultValue: {} },
  },
  {
    modelName: 'User',
    tableName: USER_TABLE_NAME,
    sequelize,
    timestamps: true,
    indexes: [
      {
        name: 'users_emailLookupHash_key',
        unique: true,
        fields: ['emailLookupHash'],
      },
      {
        name: 'users_updatedAt_idx',
        fields: ['updatedAt'],
      },
    ],
  },
);
