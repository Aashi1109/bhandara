import { afterEach, vi } from "vitest";
import { mockRedis, mockSupabase, resetExternalMocks } from "./mocks/external";

process.env.NODE_ENV = "test";
process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_ANON_KEY = "test-key";
process.env.JWT_SECRET = "test-secret";

vi.mock("@sentry/node", () => ({
  captureException: vi.fn(),
  flush: vi.fn().mockResolvedValue(undefined),
  setupExpressErrorHandler: vi.fn(),
}));

vi.mock("@/config/prometheus.config", () => ({
  httpRequestCounter: { inc: vi.fn() },
  register: {
    contentType: "text/plain",
    metrics: vi.fn().mockResolvedValue(""),
  },
  responseTimeHistogram: {
    startTimer: vi.fn(() => vi.fn()),
  },
}));

vi.mock("@/docs/swagger", () => ({
  swaggerSpec: {},
}));

vi.mock("@/logger", () => ({
  default: {
    debug: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warn: vi.fn(),
  },
}));

vi.mock("@/socket/emitter", () => ({
  emitSocketEvent: vi.fn(),
}));

vi.mock("@/connections/redis", () => ({
  disconnectRedisConnections: vi.fn(),
  getRedisConnection: vi.fn(() => mockRedis),
  getRedisConnections: vi.fn(() => ({ default: mockRedis })),
}));

vi.mock("@/connections", () => ({
  disconnectRedisConnections: vi.fn(),
  getRedisConnection: vi.fn(() => mockRedis),
  getRedisConnections: vi.fn(() => ({ default: mockRedis })),
  supabase: mockSupabase,
}));

resetExternalMocks();

afterEach(() => {
  vi.clearAllMocks();
  resetExternalMocks();
});
