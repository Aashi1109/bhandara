import { getDBConnection } from "@/connections/db";
import { getUUIDv7 } from "@/helpers";
import type {
  IEntityEngagement,
  IEntityEngagementStats,
  IEntityRating,
} from "@/definitions/types";
import { DataTypes, Model } from "sequelize";

import {
  ENTITY_ENGAGEMENT_TABLE_NAME,
  ENTITY_RATING_TABLE_NAME,
} from "./constants";

type EntityEngagementAttributes = Omit<
  IEntityEngagement,
  "createdAt" | "updatedAt" | "deletedAt"
>;

type EntityRatingAttributes = Omit<
  IEntityRating,
  "createdAt" | "updatedAt" | "deletedAt"
>;

export class EntityEngagement extends Model<
  EntityEngagementAttributes,
  EntityEngagementAttributes
> {
  declare id: string;
  declare entityType: string;
  declare entityId: string;
  declare stats: IEntityEngagementStats;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date | null;
}

export class EntityRating extends Model<
  EntityRatingAttributes,
  EntityRatingAttributes
> {
  declare id: string;
  declare entityType: string;
  declare entityId: string;
  declare userId: string;
  declare value: number;
  declare review?: string | null;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date | null;
}

EntityEngagement.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    entityType: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    entityId: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    stats: {
      type: DataTypes.JSONB,
      allowNull: false,
      defaultValue: {},
    },
  },
  {
    modelName: "EntityEngagement",
    tableName: ENTITY_ENGAGEMENT_TABLE_NAME,
    sequelize: getDBConnection(),
    timestamps: true,
    paranoid: true,
    indexes: [
      { unique: true, fields: ["entityType", "entityId"] },
      { fields: ["updatedAt"] },
    ],
  },
);

EntityRating.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    entityType: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    entityId: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: "Users", key: "id" },
    },
    value: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    review: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    modelName: "EntityRating",
    tableName: ENTITY_RATING_TABLE_NAME,
    sequelize: getDBConnection(),
    timestamps: true,
    paranoid: true,
    indexes: [
      { unique: true, fields: ["entityType", "entityId", "userId"] },
      { fields: ["entityType", "entityId"] },
      { fields: ["userId", "updatedAt"] },
    ],
  },
);
