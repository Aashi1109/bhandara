import config from '../config';
import * as HyperDX from '@hyperdx/node-opentelemetry';

const isOtelEndpointConfigured = () => {
  const u = config.otel.url?.trim();
  return typeof u === 'string' && u.length > 0 && (u.startsWith('http://') || u.startsWith('https://'));
};

const isApiPath = (url?: string) => {
  if (!url) {
    return false;
  }

  try {
    return new URL(url, 'http://localhost').pathname.startsWith('/api');
  } catch {
    return url.startsWith('/api');
  }
};

export const initializeTracing = () => {
  if (!isOtelEndpointConfigured()) {
    return;
  }

  HyperDX.init({
    url: config.otel.url,
    apiKey: config.otel.apiKey,
    service: config.infrastructure.serviceName,
    disableMetrics: !config.otel.enableMetrics,
    stopOnTerminationSignals: false,
    instrumentations: {
      '@opentelemetry/instrumentation-http': {
        enabled: true,
        ignoreIncomingRequestHook: (req: { url?: string }) => !isApiPath(req.url),
      },
      '@opentelemetry/instrumentation-express': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-pg': {
        enabled: config.otel.enableDbClientSpans,
      },
      '@opentelemetry/instrumentation-ioredis': {
        enabled: config.otel.enableRedisClientSpans,
      },
      '@opentelemetry/instrumentation-redis': {
        enabled: config.otel.enableRedisClientSpans,
      },
      '@opentelemetry/instrumentation-generic-pool': {
        enabled: false,
      },
    },
  } as Parameters<typeof HyperDX.init>[0] & { url: string });

  console.log('OpenTelemetry tracing initialized');
};

export const shutdownTracing = async (): Promise<void> => {
  await HyperDX.shutdown();
};
