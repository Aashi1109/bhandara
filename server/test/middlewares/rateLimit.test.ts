import type { NextFunction, Request, Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mockRedis } from '../mocks/external';
import { REDIS_CONNECTION_NAMES } from '@/src/common/constants';

describe('rateLimit middleware', () => {
  beforeEach(() => {
    vi.resetModules();
    mockRedis.incr.mockResolvedValue(1);
    mockRedis.expire.mockResolvedValue(1);
  });

  it('sets rate-limit headers on the first hit', async () => {
    const { default: rateLimit } = await import('@/app/server/middlewares/rateLimit');
    const { getRedisConnection } = await import('@/src/common/connections');
    const middleware = rateLimit({
      keyPrefix: 'public-user-query',
      limit: 10,
      windowSeconds: 60,
    });

    const req = {
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
    } as Request;
    const res = {
      json: vi.fn(),
      setHeader: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;
    const next = vi.fn() as unknown as NextFunction;

    await middleware(req, res, next);

    expect(mockRedis.incr).toHaveBeenCalled();
    expect(mockRedis.expire).toHaveBeenCalled();
    expect(getRedisConnection).toHaveBeenCalledWith(REDIS_CONNECTION_NAMES.RateLimit);
    expect((res.setHeader as any).mock.calls).toEqual([
      ['X-RateLimit-Limit', '10'],
      ['X-RateLimit-Remaining', '9'],
      ['X-RateLimit-Window', '60'],
    ]);
    expect(next).toHaveBeenCalledWith();
  });

  it('returns 429 when the limit is exceeded', async () => {
    mockRedis.incr.mockResolvedValue(11);

    const { default: rateLimit } = await import('@/app/server/middlewares/rateLimit');
    const middleware = rateLimit({
      keyPrefix: 'public-user-query',
      limit: 10,
      windowSeconds: 60,
    });

    const req = {
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
    } as Request;
    const res = {
      json: vi.fn(),
      setHeader: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;
    const next = vi.fn() as unknown as NextFunction;

    await middleware(req, res, next);

    expect(res.status).toHaveBeenCalledWith(429);
    expect(res.json).toHaveBeenCalledWith({
      data: null,
      error: 'Too many requests. Please try again later.',
    });
    expect(next).not.toHaveBeenCalled();
  });

  it('propagates redis failures to next(error)', async () => {
    const redisError = new Error('redis unavailable');
    mockRedis.incr.mockRejectedValue(redisError);

    const { default: rateLimit } = await import('@/app/server/middlewares/rateLimit');
    const middleware = rateLimit({
      keyPrefix: 'public-user-query',
      limit: 10,
      windowSeconds: 60,
    });

    const req = {
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
    } as Request;
    const res = {
      json: vi.fn(),
      setHeader: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;
    const next = vi.fn() as unknown as NextFunction;

    await middleware(req, res, next);

    expect(next).toHaveBeenCalledWith(redisError);
  });
});
