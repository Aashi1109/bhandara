import type { NextFunction, Request, Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { addErrorMock, addRequestMock, recordMock } = vi.hoisted(() => ({
  addErrorMock: vi.fn(),
  addRequestMock: vi.fn(),
  recordMock: vi.fn(),
}));

vi.mock('@/config/metrics.config', async () => {
  const actual = await vi.importActual<Record<string, unknown>>('@/config/metrics.config').catch(() => ({}));
  return {
    ...actual,
    httpErrorCounter: { add: addErrorMock },
    httpRequestCounter: { add: addRequestMock },
    responseTimeHistogram: { record: recordMock },
  };
});

describe('request metrics middleware', () => {
  beforeEach(() => {
    addErrorMock.mockReset();
    addRequestMock.mockReset();
    recordMock.mockReset();
  });

  it('records request counts and latency using the resolved route path', async () => {
    const { default: requestMetrics } = await import('@/middlewares/requestMetrics');
    const listeners: Record<string, () => void> = {};
    const req = {
      baseUrl: '/api/auth',
      method: 'POST',
      originalUrl: '/api/auth/login?foo=bar',
      route: { path: '/login' },
    } as unknown as Request;
    const res = {
      on: vi.fn((event: string, handler: () => void) => {
        listeners[event] = handler;
        return res;
      }),
      statusCode: 200,
    } as unknown as Response;
    const next = vi.fn() as unknown as NextFunction;

    await requestMetrics(req, res, next);
    listeners.finish?.();

    expect(addRequestMock).toHaveBeenCalledWith(1, {
      'http.request.method': 'POST',
      'http.response.status_code': 200,
      'http.route': '/api/auth/login',
      'zentry.http.status_class': '2xx',
    });
    expect(recordMock).toHaveBeenCalledWith(expect.any(Number), {
      'http.request.method': 'POST',
      'http.response.status_code': 200,
      'http.route': '/api/auth/login',
      'zentry.http.status_class': '2xx',
    });
    expect(addErrorMock).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith();
  });

  it('records error counts for non-success responses', async () => {
    const { default: requestMetrics } = await import('@/middlewares/requestMetrics');
    const listeners: Record<string, () => void> = {};
    const req = {
      baseUrl: '/api/events',
      method: 'GET',
      originalUrl: '/api/events/evt-1',
      route: { path: '/:eventId' },
    } as unknown as Request;
    const res = {
      on: vi.fn((event: string, handler: () => void) => {
        listeners[event] = handler;
        return res;
      }),
      statusCode: 404,
    } as unknown as Response;
    const next = vi.fn() as unknown as NextFunction;

    await requestMetrics(req, res, next);
    listeners.finish?.();

    expect(addRequestMock).toHaveBeenCalledWith(1, {
      'http.request.method': 'GET',
      'http.response.status_code': 404,
      'http.route': '/api/events/:eventId',
      'zentry.http.status_class': '4xx',
    });
    expect(addErrorMock).toHaveBeenCalledWith(1, {
      'http.request.method': 'GET',
      'http.response.status_code': 404,
      'http.route': '/api/events/:eventId',
      'zentry.http.status_class': '4xx',
    });
  });
});
