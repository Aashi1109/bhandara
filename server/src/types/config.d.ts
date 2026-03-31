export interface GrafanaCloudConfig {
  prometheusRemoteWriteUrl: string;
  prometheusUsername: string;
  prometheusPassword: string;
}

export interface ServiceabilityConfig {
  loki: {
    url: string;
    batchSize: number;
    flushInterval: number;
  };
}

export interface InfrastructureConfig {
  appName: string;
  serviceName: string;
}

export interface RedisConnectionConfig {
  host: string;
  port: number;
  password?: string;
  db?: number;
  tls?: Record<string, never>;
}

export interface AppConfig {
  baseUrl: string;
  port: string | number;
  jwt: {
    secret: string | undefined;
    expiresIn: string;
  };
  cloudinary: {
    cloudName: string | undefined;
    apiKey: string | undefined;
    apiSecret: string | undefined;
    secure: boolean;
    folderPath: string | undefined;
    uploadPreset: string | undefined;
  };
  dbUrl: string | undefined;
  saltRounds: number;
  express: {
    fileSizeLimit: string;
  };
  corsOptions: {
    origin: string[];
    optionsSuccessStatus: number;
    credentials: boolean;
  };
  log: {
    allLogsPath: string;
    errorLogsPath: string;
  };
  supabase: {
    url: string;
    key: string;
  };
  redis: {
    [key: string]: RedisConnectionConfig;
  };
  sessionCookie: {
    keyName: string;
    maxAge: number;
  };
  google: {
    webClientId: string;
    clientSecret: string;
    androidClientId: string;
    iosClientId: string;
  };
  db: {
    [key: string]: string | undefined;
  };
  infrastructure: InfrastructureConfig;
  serviceability: ServiceabilityConfig;
  grafanaCloud: GrafanaCloudConfig;
  sentry: SentryConfig;
  otel: OTelConfig;
}

export interface SentryConfig {
  dsn: string | undefined;
  environment: string;
  release: string;
}

export interface OTelConfig {
  url: string;
  headers: Record<string, string>;
}
