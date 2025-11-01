import * as dotenv from "dotenv";
import path from "path";
import { DB_CONNECTION_NAMES, REDIS_CONNECTION_NAMES } from "@/constants";
import { AppConfig } from "@/types/config";

dotenv.config({ path: path.join(__dirname, "../.env") });

const config: AppConfig = {
  baseUrl:
    process.env.CLOUD_RUN_SERVICE_URL ||
    `http://localhost:${process.env.PORT || 3001}`,
  port: process.env.PORT || 3001,
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || "30d",
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
    fileSizeLimit: process.env.EXPRESS_FILE_SIZE_LIMIT || "20mb",
  },
  corsOptions: {
    origin: process.env.CORS_ORIGIN?.split(",") || [
      "http://localhost:8081",
      "https://editor.swagger.io",
      "https://brave-wren-big.ngrok-free.app",
    ],
    optionsSuccessStatus: 200,
    credentials: true,
  },
  log: {
    allLogsPath: process.env.LOG_ALL_LOGS_PATH || "./logs/server.log",
    errorLogsPath: process.env.LOG_ERROR_LOGS_PATH || "./logs/error.log",
  },
  supabase: {
    url: process.env.SUPABASE_URL || "",
    key: process.env.SUPABASE_ANON_KEY || "",
  },
  redis: {
    [REDIS_CONNECTION_NAMES.Default]: {
      url: process.env.UPSTASH_REDIS_REST_URL || "",
      token: process.env.UPSTASH_REDIS_REST_TOKEN || "",
    },
  },
  ip2location: {
    apiKey: process.env.IP2LOCATION_API_KEY || "",
  },
  sessionCookie: {
    keyName: "bh_session",
    maxAge: +(process.env.SESSION_COOKIE_MAX_AGE || 1000 * 60 * 60 * 24 * 30),
  },
  google: {
    webClientId: process.env.GOOGLE_WEB_CLIENT_ID || "",
    clientSecret: process.env.GOOGLE_CLIENT_SECRET || "",
    androidClientId: process.env.GOOGLE_ANDROID_CLIENT_ID || "",
    iosClientId: process.env.GOOGLE_IOS_CLIENT_ID || "",
  },
  db: {
    [DB_CONNECTION_NAMES.Default]: process.env.DATABASE_URL || "",
  },
  infrastructure: {
    appName: "bhandara",
    serviceName: "bhandara-main-server",
  },
  serviceability: {
    loki: {
      url: process.env.LOKI_URL || "",
      batchSize: +(process.env.LOKI_BATCH_SIZE || 2),
      flushInterval: +(process.env.LOKI_FLUSH_INTERVAL || 1000),
    },
  },
  grafanaCloud: {
    prometheusRemoteWriteUrl:
      process.env.GRAFANA_CLOUD_PROMETHEUS_REMOTE_WRITE_URL || "",
    prometheusUsername: process.env.GRAFANA_CLOUD_PROMETHEUS_USERNAME || "",
    prometheusPassword: process.env.GRAFANA_CLOUD_PROMETHEUS_PASSWORD || "",
  },
  sentry: {
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || "development",
    release: process.env.npm_package_version || "0.0.0",
  },
  otel: {
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || "",
    headers: process.env.OTEL_EXPORTER_OTLP_HEADERS.split(",").reduce(
      (acc, curr) => {
        const idx = curr.indexOf("=");
        if (idx === -1) acc[curr] = "";
        else acc[curr.slice(0, idx)] = curr.slice(idx + 1);
        return acc;
      },
      {} as Record<string, string>
    ),
  },
};

export const WORKER_CONNECTION_CONFIG = {
  host: config.redis.default.url.replace("https://", ""),
  password: config.redis.default.token,
  tls: {},
  port: 6379,
};

export default config;
