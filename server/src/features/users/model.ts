import { getDBConnection } from "@connections/db";
import { DataTypes, Model } from "sequelize";
import { getUUIDv7 } from "@helpers";
import { USER_TABLE_NAME } from "./constants";
import { IBaseUser } from "@/definitions/types";

const sequelize = getDBConnection();
type UserAttributes = Omit<
  IBaseUser,
  "createdAt" | "updatedAt" | "deletedAt" | "media" | "profilePic"
> & {
  profilePic: Record<string, any> | null;
  media?: any;
};

export class User extends Model<UserAttributes, UserAttributes> {
  declare id: string;
  declare name: string;
  declare email: string;
  declare gender: string;
  declare address: Record<string, any> | null;
  declare isVerified: boolean;
  declare profilePic: Record<string, any> | null;
  declare mediaId: string | null;
  declare username?: string;
  declare password: string | null;
  declare meta: Record<string, any>;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date;
  declare media?: any;
}

User.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    name: { type: DataTypes.TEXT, allowNull: false },
    email: { type: DataTypes.TEXT, allowNull: false, unique: true },
    gender: { type: DataTypes.TEXT, allowNull: false },
    address: { type: DataTypes.JSONB },
    isVerified: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    profilePic: { type: DataTypes.JSONB },
    mediaId: {
      type: DataTypes.UUID,
      references: { model: "Media", key: "id" },
    },
    username: { type: DataTypes.TEXT },
    password: { type: DataTypes.TEXT },
    meta: { type: DataTypes.JSONB, defaultValue: {} },
  },
  {
    modelName: "User",
    tableName: USER_TABLE_NAME,
    sequelize,
    timestamps: true,
    paranoid: true,
    indexes: [
      {
        name: "users_address_gix",
        using: "GIST",
        fields: [
          sequelize.literal(
            `ST_SetSRID(ST_MakePoint(CAST("address"->'coordinates'->>'longitude' AS DOUBLE PRECISION), CAST("address"->'coordinates'->>'latitude' AS DOUBLE PRECISION)), 4326)`
          ),
        ],
      },
    ],
  }
);

(async () => {
  await User.sync({ alter: false });
})();
