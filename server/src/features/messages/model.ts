import { getDBConnection } from '@/connections/db';
import { DataTypes, Model } from 'sequelize';
import { getUUIDv7 } from '@/helpers';
import { MESSAGE_TABLE_NAME } from './constants';
import type { IMessage, IMessageStats } from '@/definitions/types';
type MessageAttributes = Omit<IMessage, 'createdAt' | 'updatedAt' | 'deletedAt' | 'user' | 'reactions'>;

export class Message extends Model<MessageAttributes, MessageAttributes> {
  declare id: string;
  declare userId: string;
  declare parentId: string | null;
  declare content: IMessage['content'];
  declare isEdited: boolean;
  declare threadId: string;
  declare stats: IMessageStats;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date;
  declare user?: any;
  declare reactions?: any[];
}

Message.init(
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
    parentId: {
      type: DataTypes.UUID,
      references: { model: 'Messages', key: 'id' },
      onDelete: 'CASCADE',
    },
    content: { type: DataTypes.JSONB, allowNull: false },
    isEdited: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    stats: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    threadId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'Threads', key: 'id' },
      onDelete: 'CASCADE',
    },
  },
  {
    modelName: 'Message',
    tableName: MESSAGE_TABLE_NAME,
    sequelize: getDBConnection(),
    timestamps: true,
    paranoid: true,
    indexes: [
      { name: 'messages_updatedAt_idx', fields: ['updatedAt'] },
    ],
  },
);
