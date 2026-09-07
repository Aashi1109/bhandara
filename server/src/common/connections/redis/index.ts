import config from '../../config';
import IORedis from 'ioredis';

import { REDIS_CONNECTION_NAMES } from '../../constants';

const redisConnections: Partial<Record<REDIS_CONNECTION_NAMES, IORedis>> = {};

export const getRedisConnections = () => redisConnections;

const connect = (name: REDIS_CONNECTION_NAMES) => {
  const connectionConfig = config.redis[name];

  return new IORedis({
    host: connectionConfig.host,
    port: connectionConfig.port,
    password: connectionConfig.password,
    db: connectionConfig.db,
    tls: connectionConfig.tls,
    lazyConnect: true,
    maxRetriesPerRequest: null,
  });
};

export async function disconnectRedisConnections() {
  const disconnecting: Promise<unknown>[] = [];
  for (const name of Object.keys(redisConnections)) {
    const connection = redisConnections[name as REDIS_CONNECTION_NAMES];
    if (!connection) {
      continue;
    }

    disconnecting.push(connection.quit().catch(() => connection.disconnect()));
  }
  return Promise.all(disconnecting);
}

export function getRedisConnection(name: REDIS_CONNECTION_NAMES = REDIS_CONNECTION_NAMES.Default): IORedis {
  if (redisConnections[name]) {
    return redisConnections[name];
  }
  if (!config.redis[name]) {
    throw new Error(`Redis connection not exists: ${name}`);
  }
  redisConnections[name] = connect(name);
  return redisConnections[name];
}
