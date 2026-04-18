import { getDBConnection } from '@/src/common/connections/db';
import { DataTypes, Model } from 'sequelize';
import { getUUIDv7 } from '@/src/common/helpers';
import { THREAD_TABLE_NAME } from './constants';
import { EAccessLevel } from '@/src/common/definitions/enums';
import type { IBaseThread, ILockHistory, IThreadStats } from '@/src/common/definitions/types';

type ThreadAttributes = Omit<IBaseThread, 'createdAt' | 'updatedAt' | 'messages' | 'creator'>;

export class Thread extends Model<ThreadAttributes, ThreadAttributes> {
  declare id: string;
  declare visibility: EAccessLevel;
  declare parentId?: string | null;
  declare eventId: string;
  declare lockHistory: ILockHistory[];
  declare stats: IThreadStats;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare createdBy: IBaseThread['createdBy'];

  declare messages?: any[];
  declare creator?: IBaseThread['creator'];
}

Thread.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    visibility: {
      type: DataTypes.ENUM(...Object.values(EAccessLevel)),
      allowNull: false,
    },
    parentId: {
      type: DataTypes.UUID,
      references: { model: 'Threads', key: 'id' },
      onDelete: 'CASCADE',
    },
    eventId: {
      type: DataTypes.UUID,
      references: { model: 'Events', key: 'id' },
      onDelete: 'CASCADE',
    },
    lockHistory: { type: DataTypes.JSONB, allowNull: false, defaultValue: [] },
    stats: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    createdBy: {
      type: DataTypes.UUID,
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    modelName: 'Thread',
    tableName: THREAD_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
    indexes: [{ name: 'threads_updatedAt_idx', fields: ['updatedAt'] }],
  },
);
