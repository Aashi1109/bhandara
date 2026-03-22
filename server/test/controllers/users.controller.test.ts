import type { Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const {
  getByIdMock,
  getUserByEmailMock,
  getUserByUsernameMock,
  trackViewMock,
  updateMock,
} = vi.hoisted(() => ({
  getByIdMock: vi.fn(),
  getUserByEmailMock: vi.fn(),
  getUserByUsernameMock: vi.fn(),
  trackViewMock: vi.fn(),
  updateMock: vi.fn(),
}));

vi.mock("@/features/users/service", () => ({
  default: class {
    getAll = vi.fn();
    getById = getByIdMock;
    getUserByEmail = getUserByEmailMock;
    getUserByUsername = getUserByUsernameMock;
    getUserInterests = vi.fn();
    update = updateMock;
  },
}));

vi.mock("@/features/engagement/service", () => ({
  default: class {
    trackView = trackViewMock;
  },
}));

describe("users controller", () => {
  beforeEach(() => {
    getByIdMock.mockReset();
    getUserByEmailMock.mockReset();
    getUserByUsernameMock.mockReset();
    updateMock.mockReset();
    trackViewMock.mockReset();
  });

  it("returns public-safe users for getUserByQuery", async () => {
    getUserByUsernameMock.mockResolvedValue({
      items: [
        {
          address: { city: "Pune" },
          email: "private@example.com",
          gender: "male",
          id: "user-2",
          mediaId: "media-1",
          meta: { auth: { provider: "email" } },
          name: "Query User",
          username: "query-user",
        },
      ],
      pagination: null,
    });

    const { getUserByQuery } = await import("@/features/users/controller");
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      query: { username: "query-user" },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await getUserByQuery(req, res);

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      data: {
        items: [
          {
            id: "user-2",
            isSocialLogin: false,
            name: "Query User",
            username: "query-user",
          },
        ],
        pagination: null,
      },
    });
  });

  it("tracks engagement and returns a safe user for getUserById", async () => {
    getByIdMock.mockResolvedValue({
      email: "private@example.com",
      id: "user-3",
      meta: { auth: { provider: "email" } },
      name: "Private User",
      password: "secret",
      username: "private-user",
    });

    const { getUserById } = await import("@/features/users/controller");
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      headers: { "user-agent": "Vitest" },
      params: { id: "user-3" },
      query: {},
      socket: { remoteAddress: "127.0.0.1" },
      user: { id: "viewer-1" },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await getUserById(req as any, res);

    expect(trackViewMock).toHaveBeenCalledWith(
      "users",
      "user-3",
      expect.objectContaining({ userId: "viewer-1" }),
    );
    expect(json).toHaveBeenCalledWith({
      data: {
        email: "private@example.com",
        id: "user-3",
        isSocialLogin: false,
        meta: { auth: { provider: "email" } },
        name: "Private User",
        username: "private-user",
      },
    });
  });

  it("strips email and password from updateUser payloads", async () => {
    updateMock.mockResolvedValue({
      email: "unchanged@example.com",
      id: "user-3",
      meta: { auth: { provider: "email" } },
      name: "Updated User",
      username: "updated-user",
    });

    const { updateUser } = await import("@/features/users/controller");
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      body: {
        email: "new@example.com",
        name: "Updated User",
        password: "secret1",
      },
      params: { id: "user-3" },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await updateUser(req as any, res);

    expect(updateMock).toHaveBeenCalledWith("user-3", { name: "Updated User" });
    expect(json).toHaveBeenCalledWith({
      data: {
        email: "unchanged@example.com",
        id: "user-3",
        isSocialLogin: false,
        meta: { auth: { provider: "email" } },
        name: "Updated User",
        username: "updated-user",
      },
    });
  });
});
