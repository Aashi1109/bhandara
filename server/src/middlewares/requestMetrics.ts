import type { NextFunction, Request, Response } from 'express';
import { httpErrorCounter, httpRequestCounter, responseTimeHistogram } from '@/config/metrics.config';

const resolveRoutePath = (req: Request) => {
  const routePath = req.route?.path;
  const baseUrl = req.baseUrl || '';

  if (typeof routePath === 'string') {
    return `${baseUrl}${routePath}` || '/';
  }

  if (Array.isArray(routePath) && routePath.length > 0) {
    return `${baseUrl}${routePath[0]}` || '/';
  }

  try {
    return new URL(req.originalUrl || req.url || '/', 'http://localhost').pathname;
  } catch {
    return req.originalUrl || req.url || '/';
  }
};

const resolveStatusClass = (statusCode: number) => `${Math.floor(statusCode / 100)}xx`;

const requestMetrics = (req: Request, res: Response, next: NextFunction) => {
  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const route = resolveRoutePath(req);
    const statusCode = res.statusCode;
    const statusClass = resolveStatusClass(statusCode);
    const attributes = {
      'http.request.method': req.method,
      'http.response.status_code': statusCode,
      'http.route': route,
      'zentry.http.status_class': statusClass,
    };

    httpRequestCounter.add(1, attributes);
    responseTimeHistogram.record(Number(process.hrtime.bigint() - start) / 1_000_000_000, attributes);

    if (statusCode >= 400) {
      httpErrorCounter.add(1, attributes);
    }
  });

  next();
};

export default requestMetrics;
