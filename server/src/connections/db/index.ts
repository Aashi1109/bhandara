import { Sequelize } from 'sequelize';
import config from '@/config';
import logger from '@/logger';
import { DB_CONNECTION_NAMES } from '@/constants';

const postgresConnection: Partial<Record<DB_CONNECTION_NAMES, Sequelize>> = {};
export const getConnections = () => postgresConnection;

const connect = (name: DB_CONNECTION_NAMES) => {
  const poolMax = Number(process.env.DB_POOL_MAX || 5);
  const poolMin = Number(process.env.DB_POOL_MIN || 1);
  const poolAcquire = Number(process.env.DB_POOL_ACQUIRE_MS || 60000);
  const poolIdle = Number(process.env.DB_POOL_IDLE_MS || 10000);

  const sequelize = new Sequelize(config.db[name], {
    logging: (msg, duration) =>
      logger.debug({
        message: msg,
        duration: typeof duration === 'number' ? duration : null,
      }),
    benchmark: process.env.NODE_ENV !== 'production',
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
      max: Number.isFinite(poolMax) ? poolMax : 5,
      min: Number.isFinite(poolMin) ? poolMin : 1,
      acquire: Number.isFinite(poolAcquire) ? poolAcquire : 60000,
      idle: Number.isFinite(poolIdle) ? poolIdle : 10000,
    },
    dialectOptions: {
      application_name: config.infrastructure.appName || 'Local',
      fallback_application_name: 'Bhandara',
    },
  });

  // Add ping method to the sequelize instance
  sequelize.ping = async () => {
    try {
      await sequelize.query('SELECT 1');
      return true;
    } catch (error) {
      logger.error('Database ping failed:', error);
      throw error;
    }
  };

  return sequelize;
};

export async function disconnect() {
  const disconnecting: Promise<void>[] = [];
  for (const connection of Object.values(postgresConnection)) {
    if (!connection) continue;
    disconnecting.push(connection.close());
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
