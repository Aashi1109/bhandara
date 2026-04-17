import { getDBConnection } from '@/connections/db';
import { EEventStatus, EEventType } from '@/definitions/enums';
import { getUUIDv7 } from '@/helpers';
import { DataTypes, Model } from 'sequelize';
import {
  type IEvent,
  type IMedia,
  type IParticipant,
  type IEventStats,
  type IVerifier,
  type IBaseUser,
  type IReaction,
} from '@/definitions/types';

const sequelize = getDBConnection()!;

type EventAttributes = Omit<IEvent, 'createdAt' | 'updatedAt' | 'location' | 'creator' | 'reactions'>;

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
  declare status: EEventStatus;
  declare capacity: number;
  declare tags: IEvent['tags'];
  declare media: IMedia[];
  declare stats: IEventStats;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare timings: IEvent['timings'];

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
    status: {
      type: DataTypes.ENUM(...Object.values(EEventStatus)),
      allowNull: false,
      defaultValue: EEventStatus.Draft,
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
    timings: {
      type: DataTypes.JSONB,
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
    ],
  },
);
