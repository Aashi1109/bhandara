import { getDBConnection } from '@/src/common/connections/db';
import type { IActivity } from '@/src/common/definitions/types';
import { getUUIDv7 } from '@/src/common/helpers';
import { DataTypes, Model } from 'sequelize';
import { ACTIVITY_TABLE_NAME, EActivityEntityType, EActivityVisibility } from './constants';

type ActivityAttributes = Omit<IActivity, 'createdAt' | 'updatedAt'>;

export class Activity extends Model<ActivityAttributes, ActivityAttributes> {
  declare id: string;
  declare actorId: string;
  declare recipientId?: string | null;
  declare type: string;
  declare entityType: EActivityEntityType;
  declare entityId: string;
  declare payload: Record<string, any>;
  declare visibility: EActivityVisibility;
  declare readAt?: Date | null;
  declare createdAt: Date;
  declare updatedAt: Date;
}

Activity.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    actorId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
    recipientId: {
      type: DataTypes.UUID,
      allowNull: true,
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
    type: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    entityType: {
      type: DataTypes.ENUM(...Object.values(EActivityEntityType)),
      allowNull: false,
    },
    entityId: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    payload: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    visibility: {
      type: DataTypes.ENUM(...Object.values(EActivityVisibility)),
      allowNull: false,
      defaultValue: EActivityVisibility.Public,
    },
    readAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    modelName: 'Activity',
    tableName: ACTIVITY_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
    indexes: [
      { fields: ['actorId', 'createdAt'] },
      { fields: ['actorId', 'updatedAt'] },
      { fields: ['recipientId', 'createdAt'] },
      { fields: ['recipientId', 'updatedAt'] },
      { fields: ['entityType', 'entityId'] },
      { fields: ['type'] },
      { fields: ['updatedAt'] },
    ],
  },
);
