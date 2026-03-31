import { getDBConnection } from '@/connections/db';
import { DataTypes, Model } from 'sequelize';
import { getUUIDv7 } from '@/helpers';
import { TAG_TABLE_NAME } from './constants';
import type { ITag } from '@/definitions/types';
type TagAttributes = Omit<ITag, 'createdAt' | 'updatedAt'>;

export class Tag extends Model<TagAttributes, TagAttributes> {
  declare id: string;
  declare name: string;
  declare value: string;
  declare description?: string | null;
  declare icon?: string | null;
  declare color?: string | null;
  declare parentId?: string | null;
  declare createdBy?: string | null;
  declare eventId?: string | null;
  declare createdAt: Date;
  declare updatedAt: Date;
}

Tag.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    name: { type: DataTypes.TEXT, allowNull: false },
    value: { type: DataTypes.TEXT, allowNull: false, unique: true },
    description: { type: DataTypes.TEXT },
    icon: { type: DataTypes.TEXT },
    color: { type: DataTypes.TEXT },
    parentId: {
      type: DataTypes.UUID,
      references: { model: 'Tags', key: 'id' },
      onDelete: 'CASCADE',
    },
    createdBy: {
      type: DataTypes.UUID,
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    modelName: 'Tag',
    tableName: TAG_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
    indexes: [{ name: 'tags_updatedAt_idx', fields: ['updatedAt'] }],
  },
);
