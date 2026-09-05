import { getDBConnection } from '@/common/connections/db';
import { EAccessLevel, EEventParticipantStatus, EEventType } from '@/common/definitions/enums';
import { getUUIDv7 } from '@/common/helpers';
import {
  DataTypes,
  Model,
  type CreationOptional,
  type InferAttributes,
  type InferCreationAttributes,
} from 'sequelize';
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
  declare visibility: EAccessLevel;
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
    visibility: {
      type: DataTypes.ENUM(...Object.values(EAccessLevel)),
      allowNull: false,
      defaultValue: EAccessLevel.Public,
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
        name: 'events_visibility_idx',
        fields: ['visibility'],
      },
      {
        name: 'events_cancelledAt_idx',
        fields: ['cancelledAt'],
      },
    ],
  },
);

export const EVENT_PARTICIPANT_TABLE_NAME = 'EventParticipants';

/**
 * One row per (event, user). A verifier is a participant with `verifiedAt` set —
 * there is no separate verifier collection.
 */
export class EventParticipant extends Model<
  InferAttributes<EventParticipant>,
  InferCreationAttributes<EventParticipant>
> {
  declare id: CreationOptional<string>;
  declare eventId: string;
  declare userId: string;
  declare status: CreationOptional<EEventParticipantStatus>;
  declare verifiedAt: CreationOptional<Date | null>;
  declare verifiedLat: CreationOptional<number | null>;
  declare verifiedLng: CreationOptional<number | null>;
  declare invitedBy: CreationOptional<string | null>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;
}

EventParticipant.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    eventId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'Events', key: 'id' },
      onDelete: 'CASCADE',
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: 'Users', key: 'id' },
      onDelete: 'CASCADE',
    },
    status: {
      type: DataTypes.ENUM(...Object.values(EEventParticipantStatus)),
      allowNull: false,
      defaultValue: EEventParticipantStatus.Pending,
    },
    verifiedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    verifiedLat: {
      type: DataTypes.DOUBLE,
      allowNull: true,
    },
    verifiedLng: {
      type: DataTypes.DOUBLE,
      allowNull: true,
    },
    invitedBy: {
      type: DataTypes.UUID,
      allowNull: true,
      references: { model: 'Users', key: 'id' },
      onDelete: 'SET NULL',
    },
    createdAt: DataTypes.DATE,
    updatedAt: DataTypes.DATE,
  },
  {
    modelName: 'EventParticipant',
    tableName: EVENT_PARTICIPANT_TABLE_NAME,
    sequelize: getDBConnection()!,
    timestamps: true,
    indexes: [
      { name: 'event_participants_eventId_userId_idx', unique: true, fields: ['eventId', 'userId'] },
      { name: 'event_participants_userId_idx', fields: ['userId'] },
    ],
  },
);

/**
 * SQL predicate for the event rows `viewerId` is allowed to see: public events,
 * their own events, and private events they participate in. An undefined
 * viewer is anonymous and sees public events only.
 *
 * Lives outside the service because three different query builders need it —
 * Sequelize `where` clauses, the raw marker SQL, and search. A second copy of
 * this rule is how a private event leaks.
 *
 * @param eventIdColumn qualified `Events.id` column for the current query; the
 * default suits raw SQL over `"Events"`, while Sequelize's `findAll` aliases the
 * table to `"Event"`.
 */
export function buildEventVisibilitySql(viewerId?: string, eventIdColumn = '"Events"."id"'): string {
  const escape = sequelize.escape.bind(sequelize);
  const publicOnly = `"visibility" = ${escape(EAccessLevel.Public)}`;
  if (!viewerId) return publicOnly;

  const uid = escape(viewerId);
  return `(${publicOnly}
      OR "createdBy" = ${uid}
      OR EXISTS (
        SELECT 1 FROM "EventParticipants" ep
        WHERE ep."eventId" = ${eventIdColumn}
          AND ep."userId" = ${uid}
          AND ep."status" <> ${escape(EEventParticipantStatus.Declined)}
      ))`;
}

/**
 * Whether an event with `capacity` and `taken` non-declined participants has a
 * seat left.
 *
 * A null capacity means unlimited — that is what the create schema stores when
 * the organiser leaves it blank. A capacity of 0 is taken literally as "closed",
 * which is the only way the update schema (`minimum: 0`) can express it.
 */
export function hasSeatAvailable(capacity: number | null | undefined, taken: number): boolean {
  if (capacity === null || capacity === undefined) return true;
  return taken < capacity;
}
