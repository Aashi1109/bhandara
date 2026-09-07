import { vi } from "vitest";

type MockPipeline = {
  del: ReturnType<typeof vi.fn>;
  exec: ReturnType<typeof vi.fn>;
  expire: ReturnType<typeof vi.fn>;
  get: ReturnType<typeof vi.fn>;
  hdel: ReturnType<typeof vi.fn>;
  hset: ReturnType<typeof vi.fn>;
  set: ReturnType<typeof vi.fn>;
};

export const createMockPipeline = (): MockPipeline => ({
  del: vi.fn(),
  exec: vi.fn().mockResolvedValue([]),
  expire: vi.fn(),
  get: vi.fn(),
  hdel: vi.fn(),
  hset: vi.fn(),
  set: vi.fn(),
});

export const mockRedis = {
  close: vi.fn(),
  del: vi.fn(),
  expire: vi.fn(),
  get: vi.fn(),
  hdel: vi.fn(),
  hget: vi.fn(),
  hgetall: vi.fn(),
  hincrby: vi.fn(),
  incr: vi.fn(),
  keys: vi.fn(),
  lpush: vi.fn(),
  lrange: vi.fn(),
  ping: vi.fn(),
  pipeline: vi.fn<() => MockPipeline>(),
  set: vi.fn(),
  setex: vi.fn(),
  ttl: vi.fn(),
};

export const mockSupabaseAuth = {
  exchangeCodeForSession: vi.fn(),
  refreshSession: vi.fn(),
  resetPasswordForEmail: vi.fn(),
  signInWithIdToken: vi.fn(),
  signInWithOAuth: vi.fn(),
  signInWithOtp: vi.fn(),
  signInWithPassword: vi.fn(),
  signOut: vi.fn(),
  signUp: vi.fn(),
  updateUser: vi.fn(),
};

export const mockSupabase = {
  auth: mockSupabaseAuth,
};

export const mockSupabaseAdminAuth = {
  getUserById: vi.fn(),
  updateUserById: vi.fn(),
};

export const defaultSession = {
  accessToken: "access-token",
  createdAt: "2024-01-01T00:00:00.000Z",
  expiresAt: "2099-01-01T00:00:00.000Z",
  expiresIn: 3600,
  location: { city: "Pune" },
  refreshToken: "refresh-token",
  user: { id: "user-1" },
  userAgent: {
    browser: { name: "Vitest", version: "1" },
    device: { model: "Mac", vendor: "Apple" },
    os: { name: "macOS", version: "14" },
    ua: "Vitest",
  },
};

export const defaultUser = {
  createdAt: "2024-01-01T00:00:00.000Z",
  email: "user@example.com",
  id: "user-1",
  isSocialLogin: false,
  media: null,
  meta: {
    auth: {
      provider: "email",
    },
  },
  name: "Test User",
  username: "tester",
};

export const resetExternalMocks = () => {
  Object.values(mockRedis).forEach((mockValue) => {
    if (typeof mockValue === "function" && "mockReset" in mockValue) {
      mockValue.mockReset();
    }
  });

  Object.values(mockSupabaseAuth).forEach((mockValue) => {
    mockValue.mockReset();
  });

  Object.values(mockSupabaseAdminAuth).forEach((mockValue) => {
    mockValue.mockReset();
  });

  mockRedis.incr.mockResolvedValue(1);
  mockRedis.expire.mockResolvedValue(1);
  mockRedis.get.mockResolvedValue(null);
  mockRedis.hget.mockResolvedValue(null);
  mockRedis.hgetall.mockResolvedValue({});
  mockRedis.del.mockResolvedValue(1);
  mockRedis.hdel.mockResolvedValue(1);
  mockRedis.hincrby.mockResolvedValue(1);
  mockRedis.keys.mockResolvedValue([]);
  mockRedis.lpush.mockResolvedValue(1);
  mockRedis.lrange.mockResolvedValue([]);
  mockRedis.set.mockResolvedValue("OK");
  mockRedis.setex.mockResolvedValue("OK");
  mockRedis.ttl.mockResolvedValue(60);
  mockRedis.close.mockResolvedValue(undefined);
  mockRedis.ping.mockResolvedValue("PONG");
  mockRedis.pipeline.mockImplementation(() => createMockPipeline());

  mockSupabaseAuth.exchangeCodeForSession.mockResolvedValue({ data: {}, error: null });
  mockSupabaseAuth.refreshSession.mockResolvedValue({ session: defaultSession });
  mockSupabaseAuth.resetPasswordForEmail.mockResolvedValue({ error: null });
  mockSupabaseAuth.signInWithIdToken.mockResolvedValue({ data: {}, error: null });
  mockSupabaseAuth.signInWithOAuth.mockResolvedValue({
    data: { url: "https://accounts.google.com/o/oauth2/auth" },
    error: null,
  });
  mockSupabaseAuth.signInWithOtp.mockResolvedValue({ error: null });
  mockSupabaseAuth.signInWithPassword.mockResolvedValue({ data: {}, error: null });
  mockSupabaseAuth.signOut.mockResolvedValue({ error: null });
  mockSupabaseAuth.signUp.mockResolvedValue({ data: {}, error: null });
  mockSupabaseAuth.updateUser.mockResolvedValue({ error: null });
  mockSupabaseAdminAuth.getUserById.mockResolvedValue({
    data: { user: { id: 'supabase-user-1' } },
    error: null,
  });
  mockSupabaseAdminAuth.updateUserById.mockResolvedValue({ error: null });
};
