import { getDBConnection } from '@/common/connections/db';
import { EEventType } from '@/common/definitions/enums';
import { getUUIDv7 } from '@/common/helpers';
import { DataTypes, Model } from 'sequelize';
import {
  type IEvent,
  type IMedia,
  type IParticipant,
  type IEventStats,
  type IVerifier,
  type IBaseUser,
  type IReaction,
} from '@/common/definitions/types';

const sequelize = getDBConnection()!;

type EventAttributes = Omit<IEvent, 'createdAt' | 'updatedAt' | 'location' | 'creator' | 'reactions' | 'status'>;

/**
 * Sequelize model representing an event. Complex fields like participants are
 * stored as JSONB columns; location is resolved via the Addresses table.
 */
export class Event extends Model<EventAttributes, EventAttributes> {
  declare id: string;
  declare name: string;
  declare description: string;
  declare participants: IParticipant[];
  declare verifiers: IVerifier[];
  declare type: EEventType;
  declare createdBy: string;
  declare isDraft: boolean;
  declare cancelledAt: IEvent['cancelledAt'];
  declare capacity: number;
  declare tags: IEvent['tags'];
  declare media: IMedia[];
  declare stats: IEventStats;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare startTime: IEvent['startTime'];
  declare endTime: IEvent['endTime'];
  declare status: IEvent['status'];

  declare creator?: IBaseUser;
  declare reactions?: IReaction[];
}

export const EVENT_TABLE_NAME = 'Events';

Event.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    name: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    participants: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
    verifiers: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
    type: {
      type: DataTypes.ENUM(...Object.values(EEventType)),
      allowNull: false,
    },
    createdBy: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    isDraft: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    cancelledAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    capacity: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    tags: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
    media: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: [],
    },
    stats: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
    startTime: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    endTime: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  {
    modelName: 'Event',
    tableName: EVENT_TABLE_NAME,
    sequelize,
    timestamps: true,
    indexes: [
      {
        name: 'events_updatedAt_idx',
        fields: ['updatedAt'],
      },
      {
        name: 'events_startTime_idx',
        fields: ['startTime'],
      },
      {
        name: 'events_endTime_idx',
        fields: ['endTime'],
      },
      {
        name: 'events_isDraft_idx',
        fields: ['isDraft'],
      },
      {
        name: 'events_cancelledAt_idx',
        fields: ['cancelledAt'],
      },
    ],
  },
);
