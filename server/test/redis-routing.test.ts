import { beforeEach, describe, expect, it, vi } from 'vitest';
import { REDIS_CONNECTION_NAMES } from '@/common/constants';

describe('redis connection routing', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    vi.doUnmock('@/features/cache');
    vi.doUnmock('@/features/cache/redis');
    vi.doUnmock('bullmq');
  });

  it('builds worker redis config on DB 2', async () => {
    process.env.REDIS_HOST = '127.0.0.1';
    process.env.REDIS_PORT = '6379';
    process.env.REDIS_PASSWORD = '';
    process.env.REDIS_TLS = 'false';

    const { WORKER_CONNECTION_CONFIG, default: config } = await import('@/common/config');

    expect(WORKER_CONNECTION_CONFIG).toMatchObject({
      host: '127.0.0.1',
      port: 6379,
      db: 2,
    });
    expect(config.redis[REDIS_CONNECTION_NAMES.Sessions].db).toBe(1);
    expect(config.redis[REDIS_CONNECTION_NAMES.Analytics].db).toBe(3);
    expect(config.redis[REDIS_CONNECTION_NAMES.RateLimit].db).toBe(4);
    expect(config.redis[REDIS_CONNECTION_NAMES.Cache].db).toBe(5);
    expect(config.redis[REDIS_CONNECTION_NAMES.Activity].db).toBe(6);
  });

  it('routes engagement service to analytics redis', async () => {
    const { getRedisConnection } = await import('@/common/connections/redis');
    const { default: EntityEngagementService } = await import('@/features/engagement/service');

    new EntityEngagementService();

    expect(getRedisConnection).toHaveBeenCalledWith(REDIS_CONNECTION_NAMES.Analytics);
  });

  it('routes stats cache to analytics redis', async () => {
    const { getRedisConnection } = await import('@/common/connections/redis');
    const { default: EntityStatsService } = await import('@/features/stats/service');

    new EntityStatsService();

    expect(getRedisConnection).toHaveBeenCalledWith(REDIS_CONNECTION_NAMES.Analytics);
  });

  it('routes user and session caches to separate redis DBs', async () => {
    const cacheConfigs: Array<Record<string, unknown>> = [];

    vi.doMock('@/features/cache', () => ({
      RedisCache: class MockRedisCache {
        constructor(config: Record<string, unknown>) {
          cacheConfigs.push(config);
        }
      },
    }));

    await import('@/features/users/helpers');

    expect(cacheConfigs).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ connectionName: REDIS_CONNECTION_NAMES.Cache }),
        expect.objectContaining({ connectionName: REDIS_CONNECTION_NAMES.Sessions }),
      ]),
    );
  });

  it('routes activity-oriented caches to the activity redis DB', async () => {
    const cacheConfigs: Array<Record<string, unknown>> = [];

    vi.doMock('@/features/cache', () => ({
      RedisCache: class MockRedisCache {
        constructor(config: Record<string, unknown>) {
          cacheConfigs.push(config);
        }
      },
    }));

    await import('@/features/activity/helpers');
    await import('@/features/achievements/helpers');

    expect(cacheConfigs).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          connectionName: REDIS_CONNECTION_NAMES.Activity,
          namespace: 'ac',
        }),
        expect.objectContaining({
          connectionName: REDIS_CONNECTION_NAMES.Activity,
          namespace: 'ah',
        }),
      ]),
    );
  });

  it('uses compact explore cache namespace', async () => {
    const cacheConfigs: Array<Record<string, unknown>> = [];

    vi.doMock('@/features/cache', () => ({
      RedisCache: class MockRedisCache {
        constructor(config: Record<string, unknown>) {
          cacheConfigs.push(config);
        }
      },
    }));

    await import('@/features/explore/helpers');

    expect(cacheConfigs).toEqual(expect.arrayContaining([expect.objectContaining({ namespace: 'ex' })]));
  });

  it('routes bull queue connection to DB 2', async () => {
    const { WORKER_CONNECTION_CONFIG } = await import('@/common/config');

    expect(WORKER_CONNECTION_CONFIG).toEqual(expect.objectContaining({ db: 2 }));
  });
});
