import { getDBConnection } from '@/connections/db';
import type { ISavedEntity } from '@/definitions/types';
import { getUUIDv7 } from '@/helpers';
import { DataTypes, Model } from 'sequelize';

import { SAVED_ENTITY_TABLE_NAME } from './constants';

type SavedEntityAttributes = Omit<
  ISavedEntity,
  'createdAt' | 'updatedAt' | 'deletedAt'
>;

export class SavedEntity extends Model<
  SavedEntityAttributes,
  SavedEntityAttributes
> {
  declare id: string;
  declare userId: string;
  declare entityType: ISavedEntity['entityType'];
  declare entityId: string;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date | null;
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
      type: DataTypes.ENUM('event', 'thread', 'message'),
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
    sequelize: getDBConnection(),
    timestamps: true,
    paranoid: true,
    indexes: [
      { unique: true, fields: ['userId', 'entityType', 'entityId'] },
      { fields: ['userId', 'updatedAt'] },
      { fields: ['entityType', 'entityId'] },
    ],
  },
);

export default SavedEntity;
