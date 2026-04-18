import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { defaultSession } from "../mocks/external";

const {
  getUserSessionCacheMock,
  refreshSessionMock,
  setContextValueMock,
  updateUserSessionCacheMock,
} = vi.hoisted(() => ({
  getUserSessionCacheMock: vi.fn(),
  refreshSessionMock: vi.fn(),
  setContextValueMock: vi.fn(),
  updateUserSessionCacheMock: vi.fn(),
}));

vi.mock("@/src/features", async () => {
  const actual = await vi.importActual<Record<string, unknown>>("@/src/features");
  return {
    ...actual,
    AuthService: class {
      refreshSession = refreshSessionMock;
    },
    getUserSessionCache: getUserSessionCacheMock,
    updateUserSessionCache: updateUserSessionCacheMock,
  };
});

vi.mock("@/src/common", async () => {
  const actual = await vi.importActual<Record<string, unknown>>("@/src/common");
  return {
    ...actual,
    RequestContext: {
      setContextValue: setContextValueMock,
    },
  };
});

describe("sessionParser", () => {
  beforeEach(() => {
    refreshSessionMock.mockReset();
    getUserSessionCacheMock.mockReset();
    updateUserSessionCacheMock.mockReset();
    setContextValueMock.mockReset();
  });

  it("rejects requests without a session cookie", async () => {
    const { default: sessionParser } = await import("@/app/server/middlewares/sessionParser");
    const req = { cookies: {} } as Request;
    const res = {} as Response;
    const next = vi.fn() as unknown as NextFunction;

    await expect(sessionParser(req, res, next)).rejects.toMatchObject({
      message: "Missing or invalid token",
      status: 401,
    });
  });

  it("rejects requests with missing cached sessions", async () => {
    getUserSessionCacheMock.mockResolvedValue(null);

    const { default: sessionParser } = await import("@/app/server/middlewares/sessionParser");
    const req = { cookies: { bh_session: "missing-session" } } as Request;
    const res = {} as Response;
    const next = vi.fn() as unknown as NextFunction;

    await expect(sessionParser(req, res, next)).rejects.toMatchObject({
      message: "Session not found, please login again",
      status: 401,
    });
    expect(getUserSessionCacheMock).toHaveBeenCalledWith("missing-session");
  });

  it("refreshes expired sessions and updates the cache", async () => {
    getUserSessionCacheMock.mockResolvedValue({
      ...defaultSession,
      expiresAt: "2000-01-01T00:00:00.000Z",
    });
    refreshSessionMock.mockResolvedValue({
      session: {
        access_token: "new-access",
        expires_at: 2_524_608_000,
        expires_in: 7200,
        refresh_token: "new-refresh",
      },
    });
    updateUserSessionCacheMock.mockResolvedValue("OK");

    const { default: sessionParser } = await import("@/app/server/middlewares/sessionParser");
    const req = { cookies: { bh_session: "expired-session" } } as Request;
    const res = {} as Response;
    const next = vi.fn() as unknown as NextFunction;

    await sessionParser(req, res, next);

    expect(refreshSessionMock).toHaveBeenCalledWith("refresh-token");
    expect(updateUserSessionCacheMock).toHaveBeenCalledWith(
      "expired-session",
      expect.objectContaining({
        accessToken: "new-access",
        refreshToken: "new-refresh",
      }),
    );
    expect(next).toHaveBeenCalledWith();
  });

  it("attaches a valid session to the request context", async () => {
    getUserSessionCacheMock.mockResolvedValue(defaultSession);

    const { default: sessionParser } = await import("@/app/server/middlewares/sessionParser");
    const req = { cookies: { bh_session: "active-session" } } as Request;
    const res = {} as Response;
    const next = vi.fn() as unknown as NextFunction;

    await sessionParser(req, res, next);

    expect((req as any).session).toEqual(defaultSession);
    expect(setContextValueMock).toHaveBeenCalledWith("session", {
      accessToken: defaultSession.accessToken,
      refreshToken: defaultSession.refreshToken,
    });
    expect(next).toHaveBeenCalledWith();
  });
});
