import config from '@/config';
import * as HyperDX from '@hyperdx/node-opentelemetry';

const isOtelEndpointConfigured = () => {
  const u = config.otel.url?.trim();
  return typeof u === 'string' && u.length > 0 && (u.startsWith('http://') || u.startsWith('https://'));
};

export const initializeTracing = () => {
  if (!isOtelEndpointConfigured()) {
    return;
  }

  HyperDX.init({
    url: config.otel.url,
    apiKey: config.otel.apiKey,
    service: config.infrastructure.serviceName,
  });

  console.log('OpenTelemetry tracing initialized');
};

export const shutdownTracing = async (): Promise<void> => {
  // HyperDX SDK handles shutdown internally
};

process.on('SIGTERM', () => {
  process.exit(0);
});
