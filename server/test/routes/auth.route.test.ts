import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createTestApp } from '../helpers/app';
import { authHeaders, invokeApp } from '../helpers/http';
import { mockSupabaseAuth } from '../mocks/external';

const createPlatformUserMock = vi.fn();
const getUserByEmailMock = vi.fn();
const deleteUserSessionCacheMock = vi.fn();
const getUserSessionCacheListMock = vi.fn();

describe('auth routes', () => {
  beforeEach(() => {
    createPlatformUserMock.mockReset();
    getUserByEmailMock.mockReset();
    deleteUserSessionCacheMock.mockReset();
    getUserSessionCacheListMock.mockReset();

    createPlatformUserMock.mockResolvedValue({
      sessionId: 'session-123',
      user: { email: 'user@example.com', id: 'user-1' },
    });
    deleteUserSessionCacheMock.mockResolvedValue(undefined);
    getUserSessionCacheListMock.mockResolvedValue([{ createdAt: '2024-01-01T00:00:00.000Z', id: 'session-123' }]);
  });

  it('returns login success with a cookie', async () => {
    getUserByEmailMock.mockResolvedValue({
      email: 'user@example.com',
      id: 'user-1',
      meta: { auth: { provider: 'email' }, provider: 'email' },
    });
    mockSupabaseAuth.signInWithPassword.mockResolvedValue({
      data: { session: { access_token: 'token' }, user: { email: 'user@example.com' } },
      error: null,
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features');
            return {
              ...actual,
              AuthService: class {
                createPlatformUser = createPlatformUserMock;
              },
            };
          },
        },
        {
          path: '@/features/users/service',
          factory: () => ({
            default: class {
              getUserByEmail = getUserByEmailMock;
            },
          }),
        },
        {
          path: '@/features/users/helpers',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features/users/helpers');
            return {
              ...actual,
              deleteUserSessionCache: deleteUserSessionCacheMock,
              getUserSessionCacheList: getUserSessionCacheListMock,
            };
          },
        },
      ],
      activeRoutes: ['@/routes/auth.route'],
    });

    const response = await invokeApp(app, {
      body: {
        email: 'user@example.com',
        password: 'secret1',
      },
      method: 'POST',
      url: '/api/auth/login',
    });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      data: {
        session: { id: 'session-123' },
        user: { email: 'user@example.com', id: 'user-1' },
      },
    });
    expect(String(response.headers['set-cookie'])).toContain('bh_session=session-123');
  });

  it('marks auth cookies for cross-origin web requests', async () => {
    getUserByEmailMock.mockResolvedValue({
      email: 'user@example.com',
      id: 'user-1',
      meta: { auth: { provider: 'email' }, provider: 'email' },
    });
    mockSupabaseAuth.signInWithPassword.mockResolvedValue({
      data: { session: { access_token: 'token' }, user: { email: 'user@example.com' } },
      error: null,
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features');
            return {
              ...actual,
              AuthService: class {
                createPlatformUser = createPlatformUserMock;
              },
            };
          },
        },
        {
          path: '@/features/users/service',
          factory: () => ({
            default: class {
              getUserByEmail = getUserByEmailMock;
            },
          }),
        },
      ],
      activeRoutes: ['@/routes/auth.route'],
    });

    const response = await invokeApp(app, {
      body: {
        email: 'user@example.com',
        password: 'secret1',
      },
      headers: {
        host: 'brave-wren-big.ngrok-free.app',
        origin: 'http://localhost:63995',
      },
      method: 'POST',
      url: '/api/auth/login',
    });

    expect(response.status).toBe(200);
    expect(String(response.headers['set-cookie'])).toContain('SameSite=None');
    expect(String(response.headers['set-cookie'])).toContain('Secure');
    expect(String(response.headers['set-cookie'])).toContain('HttpOnly');
  });

  it('rejects invalid login payload before controller execution', async () => {
    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features');
            return {
              ...actual,
              AuthService: class {
                createPlatformUser = createPlatformUserMock;
              },
            };
          },
        },
        {
          path: '@/features/users/service',
          factory: () => ({
            default: class {
              getUserByEmail = getUserByEmailMock;
            },
          }),
        },
      ],
      activeRoutes: ['@/routes/auth.route'],
    });

    const response = await invokeApp(app, {
      body: {},
      method: 'POST',
      url: '/api/auth/login',
    });

    expect(response.status).toBe(400);
    expect(response.body.data).toBeNull();
    expect(createPlatformUserMock).not.toHaveBeenCalled();
  });

  it('rejects login for social-auth users', async () => {
    getUserByEmailMock.mockResolvedValue({
      email: 'user@example.com',
      id: 'user-1',
      meta: { auth: { provider: 'google' }, provider: 'google' },
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features');
            return {
              ...actual,
              AuthService: class {
                createPlatformUser = createPlatformUserMock;
              },
            };
          },
        },
        {
          path: '@/features/users/service',
          factory: () => ({
            default: class {
              getUserByEmail = getUserByEmailMock;
            },
          }),
        },
      ],
      activeRoutes: ['@/routes/auth.route'],
    });

    const response = await invokeApp(app, {
      body: {
        email: 'user@example.com',
        password: 'secret1',
      },
      method: 'POST',
      url: '/api/auth/login',
    });

    expect(response.status).toBe(400);
    expect(response.body.error.message).toContain('please login with the same google');
    expect(createPlatformUserMock).not.toHaveBeenCalled();
  });

  it('rejects duplicate signup attempts', async () => {
    getUserByEmailMock.mockResolvedValue({
      id: 'user-1',
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features');
            return {
              ...actual,
              AuthService: class {
                createPlatformUser = createPlatformUserMock;
              },
            };
          },
        },
        {
          path: '@/features/users/service',
          factory: () => ({
            default: class {
              getUserByEmail = getUserByEmailMock;
            },
          }),
        },
      ],
      activeRoutes: ['@/routes/auth.route'],
    });

    const response = await invokeApp(app, {
      body: {
        email: 'user@example.com',
        name: 'Test User',
        password: 'secret1',
      },
      method: 'POST',
      url: '/api/auth/signup',
    });

    expect(response.status).toBe(400);
    expect(response.body.error.message).toContain('User already exists');
  });

  it('supports authenticated session lifecycle endpoints', async () => {
    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        {
          path: '@/features',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features');
            return {
              ...actual,
              AuthService: class {
                createPlatformUser = createPlatformUserMock;
              },
            };
          },
        },
        {
          path: '@/features/users/service',
          factory: () => ({
            default: class {
              getUserByEmail = getUserByEmailMock;
            },
          }),
        },
        {
          path: '@/features/users/helpers',
          factory: async () => {
            const actual = await vi.importActual<Record<string, unknown>>('@/features/users/helpers');
            return {
              ...actual,
              deleteUserSessionCache: deleteUserSessionCacheMock,
              getUserSessionCacheList: getUserSessionCacheListMock,
            };
          },
        },
      ],
      activeRoutes: ['@/routes/auth.route'],
    });

    const sessionResponse = await invokeApp(app, {
      headers: authHeaders,
      url: '/api/auth/session',
    });
    expect(sessionResponse.status).toBe(200);
    expect(sessionResponse.body.data.user.id).toBe('user-1');
    expect(sessionResponse.body.data.session.id).toBe('test-session');

    const sessionsResponse = await invokeApp(app, {
      headers: authHeaders,
      url: '/api/auth/sessions',
    });
    expect(sessionsResponse.status).toBe(200);
    expect(sessionsResponse.body.data).toEqual([{ createdAt: '2024-01-01T00:00:00.000Z', id: 'session-123' }]);

    const deleteResponse = await invokeApp(app, {
      headers: authHeaders,
      method: 'DELETE',
      url: '/api/auth/session/session-456',
    });
    expect(deleteResponse.status).toBe(200);
    expect(deleteResponse.body.data).toBe('Session deleted');
    expect(deleteUserSessionCacheMock).toHaveBeenCalledWith('user-1', 'session-456');

    const logoutResponse = await invokeApp(app, {
      headers: authHeaders,
      url: '/api/auth/logout',
    });
    expect(logoutResponse.status).toBe(200);
    expect(logoutResponse.body.data).toBe('Logout successful');
  });
});
