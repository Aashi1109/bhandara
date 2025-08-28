import { getDBConnection } from "@/connections/db";
import { DataTypes, Model } from "sequelize";
import { getUUIDv7 } from "@/helpers";
import { REACTION_TABLE_NAME } from "./constants";
import { IBaseUser, IReaction } from "@/definitions/types";
type ReactionAttributes = Omit<
  IReaction,
  "createdAt" | "updatedAt" | "deletedAt"
>;

export class Reaction extends Model<ReactionAttributes, ReactionAttributes> {
  declare id: string;
  declare contentId: string;
  declare emoji: string;
  declare userId: string;
  declare createdAt: Date;
  declare updatedAt: Date;
  declare deletedAt?: Date;

  declare user?: IBaseUser;
}

Reaction.init(
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: () => getUUIDv7(),
    },
    contentId: { type: DataTypes.TEXT, allowNull: false },
    emoji: { type: DataTypes.TEXT, allowNull: false },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: "Users", key: "id" },
    },
  },
  {
    modelName: "Reaction",
    tableName: REACTION_TABLE_NAME,
    sequelize: getDBConnection(),
    timestamps: true,
    paranoid: true,
    indexes: [{ fields: ["contentId"] }],
  }
);

(async () => {
  await Reaction.sync({ alter: false });
})();
