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

export interface AppConfig {
  baseUrl: string;
  port: string | number;
  jwt: {
    secret: string;
    expiresIn: string;
  };
  cloudinary: {
    cloudName: string;
    apiKey: string;
    apiSecret: string;
    secure: boolean;
    folderPath: string;
    uploadPreset: string;
  };
  dbUrl: string;
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
    [key: string]: {
      url: string;
      token: string;
    };
  };
  ip2location: {
    apiKey: string;
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
    [key: string]: string;
  };
  infrastructure: InfrastructureConfig;
  serviceability: ServiceabilityConfig;
  grafanaCloud: GrafanaCloudConfig;
  sentry: SentryConfig;
  otel: OTelConfig;
}

export interface SentryConfig {
  dsn: string;
  environment: string;
  release: string;
}

export interface OTelConfig {
  url: string;
  headers: Record<string, string>;
}
