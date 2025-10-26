import "sequelize";

declare module "sequelize" {
  interface Sequelize {
    ping(): Promise<boolean>;
  }
}
