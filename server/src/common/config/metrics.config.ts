import { metrics } from '@opentelemetry/api';

type HttpServerMetrics = {
  httpRequestCounter: ReturnType<ReturnType<typeof metrics.getMeter>['createCounter']>;
  httpErrorCounter: ReturnType<ReturnType<typeof metrics.getMeter>['createCounter']>;
  responseTimeHistogram: ReturnType<ReturnType<typeof metrics.getMeter>['createHistogram']>;
};

let httpServerMetrics: HttpServerMetrics | undefined;

export const getHttpServerMetrics = (): HttpServerMetrics => {
  if (httpServerMetrics) {
    return httpServerMetrics;
  }

  const meter = metrics.getMeter('zentry-server-http', '1.0.0');
  httpServerMetrics = {
    httpRequestCounter: meter.createCounter('zentry.http.server.requests', {
      description: 'Total HTTP requests grouped by route and method',
    }),
    httpErrorCounter: meter.createCounter('zentry.http.server.errors', {
      description: 'Total HTTP error responses grouped by route and method',
    }),
    responseTimeHistogram: meter.createHistogram('zentry.http.server.duration', {
      description: 'HTTP request duration grouped by route and method',
      unit: 's',
    }),
  };

  return httpServerMetrics;
};
