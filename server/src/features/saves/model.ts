import { getDBConnection } from '@/common/connections/db';
import type { ISavedEntity } from '@/common/definitions/types';
import { getUUIDv7 } from '@/common/helpers';
import { DataTypes, Model } from 'sequelize';

import { SAVED_ENTITY_TABLE_NAME } from './constants';

type SavedEntityAttributes = Omit<ISavedEntity, 'createdAt' | 'updatedAt'>;

export class SavedEntity extends Model<SavedEntityAttributes, SavedEntityAttributes> {
  declare id: string;
  declare userId: string;
  declare entityType: ISavedEntity['entityType'];
  declare entityId: string;
  declare createdAt: Date;
  declare updatedAt: Date;
}

SavedEntity.init(
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
    entityType: {
      type: DataTypes.ENUM('event', 'thread', 'message', 'user'),
      allowNull: false,
    },
    entityId: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
  },
  {
    modelName: 'SavedEntity',
    tableName: SAVED_ENTITY_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
    indexes: [
      { unique: true, fields: ['userId', 'entityType', 'entityId'] },
      { fields: ['userId', 'updatedAt'] },
      { fields: ['entityType', 'entityId'] },
    ],
  },
);

export default SavedEntity;
