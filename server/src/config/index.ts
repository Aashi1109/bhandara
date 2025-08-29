import * as dotenv from "dotenv";
import path, { dirname } from "path";
import { DB_CONNECTION_NAMES } from "@/constants";

dotenv.config({ path: path.join(__dirname, "../.env") });

const config = {
  port: process.env.PORT || 3001,
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: "30d",
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
  saltRounds: 10,
  express: {
    fileSizeLimit: "20mb",
  },
  corsOptions: {
    origin: [
      "http://localhost:8081",
      "https://editor.swagger.io",
      "https://brave-wren-big.ngrok-free.app",
    ],
    optionsSuccessStatus: 200,
    credentials: true,
  },
  log: {
    allLogsPath: "./logs/server.log",
    errorLogsPath: "./logs/error.log",
  },
  supabase: {
    url: process.env.SUPABASE_URL || "",
    key: process.env.SUPABASE_ANON_KEY || "",
  },
  redis: {
    url: process.env.UPSTASH_REDIS_REST_URL || "",
    token: process.env.UPSTASH_REDIS_REST_TOKEN || "",
    host: process.env.REDIS_HOST || "",
    port: +process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || "",
  },
  ip2location: {
    apiKey: process.env.IP2LOCATION_API_KEY || "",
  },
  sessionCookie: {
    keyName: "bh_session",
    maxAge: 1000 * 60 * 60 * 24 * 30,
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
  },
  serviceability: {
    loki: {
      url: process.env.LOKI_URL || "",
      batchSize: +(process.env.LOKI_BATCH_SIZE || 2),
      flushInterval: +(process.env.LOKI_FLUSH_INTERVAL || 1000),
    },
  },
};

export default config;
