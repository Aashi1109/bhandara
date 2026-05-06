import { DB_CONNECTION_NAMES, REDIS_CONNECTION_NAMES } from '../constants';
import type { AppConfig, RedisConnectionConfig } from '@/src/types/config';
import dotenv from 'dotenv';

if (process.env.NODE_ENV !== 'production') {
  dotenv.config({});
}

const getRequiredSecret = (envName: string) => {
  const value = process.env[envName];
  if (!value) {
    throw new Error(`${envName} is required`);
  }

  if (!/^[^\s]{5,64}$/.test(value)) {
    throw new Error(`${envName} must be 5-64 characters with no whitespace`);
  }

  return value;
};

const getRedisBaseConnectionConfig = (): RedisConnectionConfig => {
  return {
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: +(process.env.REDIS_PORT || 6379),
    password: process.env.REDIS_PASSWORD || undefined,
    tls: process.env.REDIS_TLS === 'true' ? {} : undefined,
  };
};

const withRedisDb = (baseConfig: RedisConnectionConfig, db: number): RedisConnectionConfig => ({
  ...baseConfig,
  db,
});

const redisBaseConnection = getRedisBaseConnectionConfig();
const localhostOriginPattern = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const configuredCorsOrigins = process.env.CORS_ORIGIN?.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const defaultCorsOrigins: string[] = [];
const corsOrigins = [localhostOriginPattern, ...(configuredCorsOrigins || defaultCorsOrigins)];
const appType = (process.env.APP_TYPE as 'server' | 'worker') || 'server';
const appName = process.env.APP_NAME?.trim() || '';
const otelServiceName = process.env.OTEL_SERVICE_NAME?.trim();
const derivedServiceName = (() => {
  if (otelServiceName) {
    return otelServiceName;
  }

  const serviceParts = ['zentry', appType];
  if (appName && appName !== appType) {
    serviceParts.push(appName);
  }

  return serviceParts.join('-');
})();
const redisConnections = {
  [REDIS_CONNECTION_NAMES.Default]: withRedisDb(redisBaseConnection, 5),
  [REDIS_CONNECTION_NAMES.Cache]: withRedisDb(redisBaseConnection, 5),
  [REDIS_CONNECTION_NAMES.Sessions]: withRedisDb(redisBaseConnection, 1),
  [REDIS_CONNECTION_NAMES.Bull]: withRedisDb(redisBaseConnection, 2),
  [REDIS_CONNECTION_NAMES.Analytics]: withRedisDb(redisBaseConnection, 3),
  [REDIS_CONNECTION_NAMES.RateLimit]: withRedisDb(redisBaseConnection, 4),
  [REDIS_CONNECTION_NAMES.Activity]: withRedisDb(redisBaseConnection, 6),
} satisfies Record<REDIS_CONNECTION_NAMES, RedisConnectionConfig>;

const config: AppConfig = {
  baseUrl: process.env.CLOUD_RUN_SERVICE_URL || `http://localhost:${process.env.PORT || 3001}`,
  port: process.env.PORT || 3001,
  encryption: {
    dataKey: getRequiredSecret('DATA_ENCRYPTION_KEY'),
    hashKey: getRequiredSecret('DATA_HASH_KEY'),
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  },
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    apiKey: process.env.CLOUDINARY_API_KEY,
    apiSecret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
    folderPath: process.env.CLOUDINARY_BASE_FOLDER,
    uploadPreset: process.env.CLOUDINARY_UPLOAD_PRESET,
  },
  dbUrl: process.env.DATABASE_URL,
  saltRounds: +(process.env.SALT_ROUNDS || 10),
  express: {
    fileSizeLimit: process.env.EXPRESS_FILE_SIZE_LIMIT || '20mb',
  },
  corsOptions: {
    origin: corsOrigins,
    optionsSuccessStatus: 200,
    credentials: true,
  },
  log: {
    allLogsPath: process.env.LOG_ALL_LOGS_PATH || './logs/server.log',
    errorLogsPath: process.env.LOG_ERROR_LOGS_PATH || './logs/error.log',
  },
  supabase: {
    url: process.env.SUPABASE_URL || '',
    key: process.env.SUPABASE_ANON_KEY || '',
  },
  redis: {
    ...redisConnections,
  },
  sessionCookie: {
    keyName: 'bh_session',
    maxAge: +(process.env.SESSION_COOKIE_MAX_AGE || 1000 * 60 * 60 * 24 * 30),
  },
  google: {
    webClientId: process.env.GOOGLE_WEB_CLIENT_ID || '',
    clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
    androidClientId: process.env.GOOGLE_ANDROID_CLIENT_ID || '',
    iosClientId: process.env.GOOGLE_IOS_CLIENT_ID || '',
  },
  db: {
    [DB_CONNECTION_NAMES.Default]: process.env.DATABASE_URL || '',
  },
  infrastructure: {
    appName: 'zentry',
    serviceName: derivedServiceName,
  },
  resend: {
    apiKey: process.env.RESEND_API_KEY,
    fromEmail: process.env.RESEND_FROM_EMAIL || 'noreply@zentry.app',
    fromName: process.env.RESEND_FROM_NAME || 'Zentry',
  },
  supabaseServiceRole: process.env.SUPABASE_SERVICE_ROLE_KEY,
  sentry: {
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',
    release: process.env.npm_package_version || '0.0.0',
  },
  otel: {
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || '',
    apiKey: process.env.HYPERDX_API_KEY || '',
    enableDbClientSpans: process.env.OTEL_TRACE_DB_CLIENTS === 'true',
    enableRedisClientSpans: process.env.OTEL_TRACE_REDIS_CLIENTS === 'true',
    enableMetrics: process.env.OTEL_DISABLE_METRICS !== 'true',
  },
  appType,
  appName,
};

export const WORKER_CONNECTION_CONFIG = {
  host: redisConnections[REDIS_CONNECTION_NAMES.Bull].host,
  port: redisConnections[REDIS_CONNECTION_NAMES.Bull].port,
  password: redisConnections[REDIS_CONNECTION_NAMES.Bull].password,
  db: redisConnections[REDIS_CONNECTION_NAMES.Bull].db,
  tls: redisConnections[REDIS_CONNECTION_NAMES.Bull].tls,
  maxRetriesPerRequest: null,
};

export default config;
