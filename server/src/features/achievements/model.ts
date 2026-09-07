import { getDBConnection } from '@/common/connections/db';
import { DataTypes, Model } from 'sequelize';
import { getUUIDv7 } from '@/common/helpers';
import type { IAchievementProgress, IUserAchievement } from '@/common/definitions/types';
import { ACHIEVEMENT_PROGRESS_TABLE_NAME, USER_ACHIEVEMENT_TABLE_NAME } from './constants';

type UserAchievementAttributes = Omit<IUserAchievement, 'createdAt' | 'updatedAt'>;

type AchievementProgressAttributes = Omit<IAchievementProgress, 'createdAt' | 'updatedAt'>;

export class UserAchievement extends Model<UserAchievementAttributes, UserAchievementAttributes> {
  declare id: string;
  declare userId: string;
  declare key: string;
  declare title: string;
  declare description: string;
  declare icon?: string | null;
  declare metadata: Record<string, any>;
  declare unlockedAt: Date;
  declare createdAt: Date;
  declare updatedAt: Date;
}

export class AchievementProgress extends Model<AchievementProgressAttributes, AchievementProgressAttributes> {
  declare id: string;
  declare userId: string;
  declare metrics: Record<string, any>;
  declare createdAt: Date;
  declare updatedAt: Date;
}

UserAchievement.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
    key: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    title: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    icon: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    metadata: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    unlockedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    modelName: 'UserAchievement',
    tableName: USER_ACHIEVEMENT_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
    indexes: [{ unique: true, fields: ['userId', 'key'] }, { fields: ['userId', 'unlockedAt'] }],
  },
);

AchievementProgress.init(
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
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
    metrics: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
  },
  {
    modelName: 'AchievementProgress',
    tableName: ACHIEVEMENT_PROGRESS_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
  },
);
