import { getDBConnection } from '@/src/common/connections/db';
import { DataTypes, Model } from 'sequelize';
import { getUUIDv7 } from '@/src/common/helpers';
import { USER_TABLE_NAME } from './constants';

export const USER_SETTINGS_TABLE_NAME = 'UserSettings';

const sequelize = getDBConnection()!;

export interface UserSettingsAttributes {
  id: string;
  userId: string;
  notifications: {
    events: boolean;
    chat: boolean;
    replies: boolean;
    reminders: boolean;
  };
  privacy: {
    shareLocation: boolean;
  };
  onboarding: {
    hasOnboarded: boolean;
  };
  interests: string[];
  createdAt: Date;
  updatedAt: Date;
}

export class UserSettings extends Model<UserSettingsAttributes, UserSettingsAttributes> {
  declare id: string;
  declare userId: string;
  declare notifications: UserSettingsAttributes['notifications'];
  declare privacy: UserSettingsAttributes['privacy'];
  declare onboarding: UserSettingsAttributes['onboarding'];
  declare interests: string[];
  declare createdAt: Date;
  declare updatedAt: Date;
}

UserSettings.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
      references: {
        model: USER_TABLE_NAME,
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    notifications: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        events: true,
        chat: true,
        replies: true,
        reminders: true,
      },
    },
    privacy: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        shareLocation: false,
      },
    },
    onboarding: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {
        hasOnboarded: false,
      },
    },
    interests: {
      type: DataTypes.ARRAY(DataTypes.TEXT),
      allowNull: false,
      defaultValue: [],
    },
    createdAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    updatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  {
    modelName: USER_SETTINGS_TABLE_NAME,
    tableName: USER_SETTINGS_TABLE_NAME,
    sequelize,
    timestamps: true,
  },
);
