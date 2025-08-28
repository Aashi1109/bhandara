import { Sequelize } from "sequelize";
import config from "@/config";
import logger from "@/logger";
import { DB_CONNECTION_NAMES } from "@/constants";

const postgresConnection = {};
export const getConnections = () => {
  return postgresConnection;
};

const connect = (name: DB_CONNECTION_NAMES) => {
  return new Sequelize(config.db[name], {
    logging: (msg, duration) =>
      logger.debug({
        message: msg,
        duration: typeof duration === "number" ? duration : null,
      }),
    benchmark: process.env.NODE_ENV !== "production",
    retry: {
      max: 5,
      match: [
        /ConnectionError/,
        /SequelizeConnectionError/,
        /SequelizeConnectionRefusedError/,
        /SequelizeHostNotFoundError/,
        /SequelizeHostNotReachableError/,
        /SequelizeInvalidConnectionError/,
        /SequelizeConnectionTimedOutError/,
        /SequelizeConnectionAcquireTimeoutError/,
      ],
    },
    pool: {
      max: 20,
      min: 0,
      acquire: 60000,
      idle: 10000,
    },
    dialectOptions: {
      application_name: config.infrastructure.appName || "Local",
      fallback_application_name: "Bhandara",
    },
  });
};

export async function disconnect() {
  const disconnecting = [];
  for (const name of Object.keys(postgresConnection)) {
    disconnecting.push(postgresConnection[name].destroy());
  }
  return Promise.all(disconnecting);
}

export function getDBConnection(name?: DB_CONNECTION_NAMES.Default) {
  name ??= DB_CONNECTION_NAMES.Default;
  if (postgresConnection[name]) {
    return postgresConnection[name];
  }
  if (!config.db[name]) {
    throw new Error(`DB connection not exists: ${name}`);
  }
  postgresConnection[name] = connect(name);
  return postgresConnection[name];
}
