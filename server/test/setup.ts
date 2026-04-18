import { afterEach, vi } from 'vitest';
import { mockRedis, mockSupabase, mockSupabaseAdminAuth, resetExternalMocks } from './mocks/external';

process.env.NODE_ENV = 'test';
process.env.SUPABASE_URL = 'https://example.supabase.co';
process.env.SUPABASE_ANON_KEY = 'test-key';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-key';
process.env.JWT_SECRET = 'test-secret';
process.env.DATA_ENCRYPTION_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
process.env.DATA_HASH_KEY = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
process.env.REDIS_HOST = '127.0.0.1';
process.env.REDIS_PORT = '6379';
process.env.REDIS_PASSWORD = '';
process.env.REDIS_DB = '0';
process.env.REDIS_TLS = 'false';

vi.mock('@sentry/node', () => ({
  captureException: vi.fn(),
  flush: vi.fn().mockResolvedValue(undefined),
  setupExpressErrorHandler: vi.fn(),
}));

vi.mock('@/config/metrics.config', () => ({
  httpErrorCounter: { add: vi.fn() },
  httpRequestCounter: { add: vi.fn() },
  responseTimeHistogram: {
    record: vi.fn(),
  },
}));

vi.mock('@/docs/swagger', () => ({
  swaggerSpec: {},
}));

vi.mock('@/logger', () => ({
  default: {
    debug: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warn: vi.fn(),
  },
}));

vi.mock('@/socket/emitter', () => ({
  emitSocketEvent: vi.fn(),
}));

vi.mock('@/connections/redis', () => ({
  disconnectRedisConnections: vi.fn(),
  getRedisConnection: vi.fn(() => mockRedis),
  getRedisConnections: vi.fn(() => ({ default: mockRedis })),
}));

vi.mock('@/connections', () => ({
  disconnectRedisConnections: vi.fn(),
  getRedisConnection: vi.fn(() => mockRedis),
  getRedisConnections: vi.fn(() => ({ default: mockRedis })),
  supabase: mockSupabase,
}));

vi.mock('@/connections/supabase/admin', () => ({
  default: {
    auth: {
      admin: mockSupabaseAdminAuth,
    },
  },
}));

resetExternalMocks();

afterEach(() => {
  vi.clearAllMocks();
  resetExternalMocks();
});
