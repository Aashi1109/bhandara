import type { Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { mockSupabaseAdminAuth, mockSupabaseAuth } from "../mocks/external";

const { consumeResetTokenMock, createPlatformUserMock, getUserByEmailMock, sendPasswordResetSuccessEmailMock } =
  vi.hoisted(() => ({
    consumeResetTokenMock: vi.fn(),
  createPlatformUserMock: vi.fn(),
  getUserByEmailMock: vi.fn(),
    sendPasswordResetSuccessEmailMock: vi.fn(),
  }));

vi.mock("@/features", async () => {
  const actual = await vi.importActual<Record<string, unknown>>("@/features");
  return {
    ...actual,
    AuthService: class {
      createPlatformUser = createPlatformUserMock;
    },
  };
});

vi.mock("@/features/users/service", () => ({
  default: class {
    getUserByEmail = getUserByEmailMock;
  },
}));

vi.mock("@/features/auth/otp-helpers", async () => {
  const actual = await vi.importActual<Record<string, unknown>>("@/features/auth/otp-helpers");
  return {
    ...actual,
    consumeResetToken: consumeResetTokenMock,
  };
});

vi.mock("@/services/email", () => ({
  sendPasswordResetOTPEmail: vi.fn(),
  sendPasswordResetSuccessEmail: sendPasswordResetSuccessEmailMock,
}));

describe("auth controller", () => {
  beforeEach(() => {
    consumeResetTokenMock.mockReset();
    createPlatformUserMock.mockReset();
    getUserByEmailMock.mockReset();
    sendPasswordResetSuccessEmailMock.mockReset();
  });

  it("returns 400 when Google id-token exchange does not yield an access token", async () => {
    mockSupabaseAuth.signInWithIdToken.mockResolvedValue({ data: {}, error: null });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        json: vi.fn().mockResolvedValue({ id_token: "id-token" }),
      }),
    );

    const { signInWithIdToken } = await import("@/features/auth/controller");
    const req = {
      body: {
        code: "oauth-code",
        codeVerifier: "verifier",
        redirectUri: "app://callback",
      },
      headers: {
        "x-client-platform": "android",
      },
    } as unknown as Request;
    const res = {} as Response;

    await expect(signInWithIdToken(req, res)).rejects.toMatchObject({
      message: "Invalid access token",
      status: 400,
    });
  });

  it("returns session and user payload for successful login", async () => {
    getUserByEmailMock.mockResolvedValue({
      email: "user@example.com",
      id: "user-1",
      meta: { auth: { provider: "email" }, provider: "email" },
    });
    mockSupabaseAuth.signInWithPassword.mockResolvedValue({
      data: { session: { access_token: "access-token" }, user: { email: "user@example.com" } },
      error: null,
    });
    createPlatformUserMock.mockResolvedValue({
      sessionId: "session-123",
      user: { email: "user@example.com", id: "user-1" },
    });

    const { login } = await import("@/features/auth/controller");
    const cookie = vi.fn();
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      body: {
        email: "user@example.com",
        password: "secret1",
      },
    } as Request;
    const res = {
      cookie,
      json,
      status,
    } as unknown as Response;

    await login(req, res);

    expect(cookie).toHaveBeenCalledWith(
      "bh_session",
      "session-123",
      expect.objectContaining({ maxAge: expect.any(Number) }),
    );
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      data: {
        session: { id: "session-123" },
        user: { email: "user@example.com", id: "user-1" },
      },
    });
  });

  it("uses the persisted __sid for password resets", async () => {
    consumeResetTokenMock.mockResolvedValue("user@example.com");
    getUserByEmailMock.mockResolvedValue({
      __sid: "supabase-user-42",
      email: "user@example.com",
      id: "user-1",
      meta: { auth: { provider: "email" } },
    });
    mockSupabaseAdminAuth.getUserById.mockResolvedValue({
      data: { user: { id: "supabase-user-42" } },
      error: null,
    });
    mockSupabaseAdminAuth.updateUserById.mockResolvedValue({ error: null });

    const { resetPassword } = await import("@/features/auth/controller");
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      body: {
        email: "user@example.com",
        password: "new-password-123",
        token: "reset-token",
      },
    } as unknown as Request;
    const res = {
      json,
      status,
    } as unknown as Response;

    await resetPassword(req, res);

    expect(mockSupabaseAdminAuth.getUserById).toHaveBeenCalledWith("supabase-user-42");
    expect(mockSupabaseAdminAuth.updateUserById).toHaveBeenCalledWith("supabase-user-42", {
      password: "new-password-123",
    });
    expect(sendPasswordResetSuccessEmailMock).toHaveBeenCalledWith("user@example.com");
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({ data: "Password reset successfully" });
  });
});
