import { metrics } from '@opentelemetry/api';

const meter = metrics.getMeter('zentry-server-http', '1.0.0');

export const httpRequestCounter = meter.createCounter('zentry.http.server.requests', {
  description: 'Total HTTP requests grouped by route and method',
});

export const httpErrorCounter = meter.createCounter('zentry.http.server.errors', {
  description: 'Total HTTP error responses grouped by route and method',
});

export const responseTimeHistogram = meter.createHistogram('zentry.http.server.duration', {
  description: 'HTTP request duration grouped by route and method',
  unit: 's',
});
