import { beforeEach, describe, expect, it, vi } from "vitest";
import { createTestApp } from "../helpers/app";
import { authHeaders, invokeApp } from "../helpers/http";
import { mockRedis } from "../mocks/external";

const getUserByEmailMock = vi.fn();
const getUserByUsernameMock = vi.fn();
const getByIdMock = vi.fn();
const updateMock = vi.fn();
const trackViewMock = vi.fn();

describe("users routes", () => {
  beforeEach(() => {
    getUserByEmailMock.mockReset();
    getUserByUsernameMock.mockReset();
    getByIdMock.mockReset();
    updateMock.mockReset();
    trackViewMock.mockReset();
  });

  it("returns a public-safe user shape from /query", async () => {
    getUserByEmailMock.mockResolvedValue({
      address: { city: "Pune" },
      email: "public@example.com",
      gender: "male",
      id: "user-2",
      mediaId: "media-1",
      meta: { auth: { provider: "email" } },
      name: "Public User",
      username: "public-user",
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: "@/src/features/users/service",
          factory: () => ({
            default: class {
              getAll = vi.fn();
              getById = getByIdMock;
              getUserByEmail = getUserByEmailMock;
              getUserByUsername = getUserByUsernameMock;
              getUserInterests = vi.fn();
              update = updateMock;
            },
          }),
        },
        {
          path: "@/src/features/engagement/service",
          factory: () => ({
            default: class {
              trackView = trackViewMock;
            },
          }),
        },
      ],
      activeRoutes: ["@/app/server/routes/users.route"],
    });

    const response = await invokeApp(app, {
      url: "/api/users/query?email=public@example.com",
    });

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0]).toMatchObject({
      id: "user-2",
      name: "Public User",
      username: "public-user",
    });
    expect(response.body.data.items[0].email).toBeUndefined();
    expect(response.body.data.items[0].meta).toBeUndefined();
  });

  it("applies rate-limit headers and returns 429 when the limit is exceeded", async () => {
    getUserByUsernameMock.mockResolvedValue({
      items: [],
      pagination: null,
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: "@/src/features/users/service",
          factory: () => ({
            default: class {
              getAll = vi.fn();
              getById = getByIdMock;
              getUserByEmail = getUserByEmailMock;
              getUserByUsername = getUserByUsernameMock;
              getUserInterests = vi.fn();
              update = updateMock;
            },
          }),
        },
        {
          path: "@/src/features/engagement/service",
          factory: () => ({
            default: class {
              trackView = trackViewMock;
            },
          }),
        },
      ],
      activeRoutes: ["@/app/server/routes/users.route"],
    });

    mockRedis.incr.mockResolvedValueOnce(1).mockResolvedValueOnce(11);

    const okResponse = await invokeApp(app, {
      url: "/api/users/query?username=public-user",
    });
    expect(okResponse.status).toBe(200);
    expect(okResponse.headers["x-ratelimit-limit"]).toBe("10");
    expect(okResponse.headers["x-ratelimit-remaining"]).toBe("9");

    const limitedResponse = await invokeApp(app, {
      url: "/api/users/query?username=public-user",
    });
    expect(limitedResponse.status).toBe(429);
    expect(limitedResponse.body).toEqual({
      data: null,
      error: "Too many requests. Please try again later.",
    });
  });

  it("returns a sanitized authenticated user for GET /:id", async () => {
    getByIdMock.mockResolvedValue({
      email: "private@example.com",
      id: "user-3",
      meta: { auth: { provider: "email" } },
      name: "Private User",
      password: "secret",
      username: "private-user",
    });

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        {
          path: "@/src/features/users/service",
          factory: () => ({
            default: class {
              getAll = vi.fn();
              getById = getByIdMock;
              getUserByEmail = getUserByEmailMock;
              getUserByUsername = getUserByUsernameMock;
              getUserInterests = vi.fn();
              update = updateMock;
            },
          }),
        },
        {
          path: "@/src/features/engagement/service",
          factory: () => ({
            default: class {
              trackView = trackViewMock;
            },
          }),
        },
      ],
      activeRoutes: ["@/app/server/routes/users.route"],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: "/api/users/user-3",
    });

    expect(response.status).toBe(200);
    expect(response.body.data).toMatchObject({
      email: "private@example.com",
      id: "user-3",
      name: "Private User",
      username: "private-user",
    });
    expect(response.body.data.password).toBeUndefined();
    expect(trackViewMock).toHaveBeenCalledWith(
      "users",
      "user-3",
      expect.objectContaining({ userId: "user-1" }),
    );
  });

  it("rejects unauthenticated access to protected users routes", async () => {
    const app = await createTestApp({
      moduleMocks: [
        {
          path: "@/src/features/users/service",
          factory: () => ({
            default: class {
              getAll = vi.fn();
              getById = getByIdMock;
              getUserByEmail = getUserByEmailMock;
              getUserByUsername = getUserByUsernameMock;
              getUserInterests = vi.fn();
              update = updateMock;
            },
          }),
        },
        {
          path: "@/src/features/engagement/service",
          factory: () => ({
            default: class {
              trackView = trackViewMock;
            },
          }),
        },
      ],
      activeRoutes: ["@/app/server/routes/users.route"],
    });

    const response = await invokeApp(app, {
      url: "/api/users/user-3",
    });

    expect(response.status).toBe(401);
    expect(response.body.data).toBeNull();
  });

  it("rejects invalid PATCH bodies that try to send forbidden fields", async () => {
    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        {
          path: "@/src/features/users/service",
          factory: () => ({
            default: class {
              getAll = vi.fn();
              getById = getByIdMock;
              getUserByEmail = getUserByEmailMock;
              getUserByUsername = getUserByUsernameMock;
              getUserInterests = vi.fn();
              update = updateMock;
            },
          }),
        },
        {
          path: "@/src/features/engagement/service",
          factory: () => ({
            default: class {
              trackView = trackViewMock;
            },
          }),
        },
      ],
      activeRoutes: ["@/app/server/routes/users.route"],
    });

    const response = await invokeApp(app, {
      body: { email: "new@example.com", password: "secret1" },
      headers: authHeaders,
      method: "PATCH",
      url: "/api/users/user-3",
    });

    expect(response.status).toBe(400);
    expect(updateMock).not.toHaveBeenCalled();
  });
});
