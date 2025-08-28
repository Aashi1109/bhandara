import { getDBConnection } from "@/connections/db";
import { DataTypes, Model } from "sequelize";
import { getUUIDv7 } from "@/helpers";
import { THREAD_TABLE_NAME } from "./constants";
import { EThreadType, EAccessLevel } from "@/definitions/enums";
import { IBaseThread, ILockHistory } from "@/definitions/types";

type ThreadAttributes = Omit<
  IBaseThread,
  "createdAt" | "updatedAt" | "deletedAt" | "messages" | "creator"
>;

export class Thread extends Model<ThreadAttributes, ThreadAttributes> {
  declare id: string;
  declare type: EThreadType;
  declare visibility: EAccessLevel;
  declare parentId?: string | null;
  declare eventId: string;
  declare lockHistory: ILockHistory[];
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date;
  declare createdBy: IBaseThread["createdBy"];

  declare messages?: any[];
  declare creator?: IBaseThread["creator"];
}

Thread.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    type: {
      type: DataTypes.ENUM(...Object.values(EThreadType)),
      allowNull: false,
    },
    visibility: {
      type: DataTypes.ENUM(...Object.values(EAccessLevel)),
      allowNull: false,
    },
    parentId: {
      type: DataTypes.UUID,
      references: { model: "Threads", key: "id" },
    },
    eventId: {
      type: DataTypes.UUID,
      references: { model: "Events", key: "id" },
    },
    lockHistory: { type: DataTypes.JSONB, defaultValue: {} },
    createdBy: {
      type: DataTypes.UUID,
      references: { model: "Users", key: "id" },
    },
  },
  {
    modelName: "Thread",
    tableName: THREAD_TABLE_NAME,
    sequelize: getDBConnection(),
    timestamps: true,
    paranoid: true,
  }
);

(async () => {
  await Thread.sync({ alter: false });
})();
