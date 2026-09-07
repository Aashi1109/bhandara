import { beforeEach, describe, expect, it, vi } from "vitest";

import { BadRequestError } from "@/common/exceptions";
import { createTestApp } from "../helpers/app";
import { authHeaders, invokeApp } from "../helpers/http";

const getSaveStateMock = vi.fn();
const listSavedEntitiesMock = vi.fn();
const saveEntityMock = vi.fn();
const unsaveEntityMock = vi.fn();

describe("saves routes", () => {
  beforeEach(() => {
    getSaveStateMock.mockReset();
    listSavedEntitiesMock.mockReset();
    saveEntityMock.mockReset();
    unsaveEntityMock.mockReset();
  });

  it("lists saved profiles with query filters", async () => {
    listSavedEntitiesMock.mockResolvedValue({
      items: [
        {
          entity: {
            id: "user-2",
            name: "Public User",
            username: "public-user",
          },
          entityId: "user-2",
          entityType: "user",
          id: "save-1",
          userId: "user-1",
        },
      ],
      pagination: {
        hasNext: false,
        limit: 20,
        next: null,
        sortBy: "updatedAt",
        sortOrder: "desc",
        total: 1,
      },
    });

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        {
          path: "@/features/saves/service",
          factory: () => ({
            default: class {
              getSaveState = getSaveStateMock;
              listSavedEntities = listSavedEntitiesMock;
              saveEntity = saveEntityMock;
              unsaveEntity = unsaveEntityMock;
              validateEntityType(entityType: string) {
                if (!["event", "thread", "message", "user"].includes(entityType)) {
                  throw new BadRequestError("Unsupported entity type");
                }
                return entityType;
              }
            },
          }),
        },
      ],
      activeRoutes: ["@app/server/routes/saves.route"],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: "/api/saves?entityType=user&query=pub&limit=20",
    });

    expect(response.status).toBe(200);
    expect(listSavedEntitiesMock).toHaveBeenCalledWith(
      "user-1",
      { entityType: "user", query: "pub" },
      expect.objectContaining({
        limit: 20,
        sortBy: "updatedAt",
        sortOrder: "desc",
      }),
    );
    expect(response.body.data.items[0]).toMatchObject({
      entityId: "user-2",
      entityType: "user",
    });
  });

  it("returns save state for user entities", async () => {
    getSaveStateMock.mockResolvedValue({
      entityId: "user-2",
      entityType: "user",
      saveCount: 3,
      saved: true,
      savedAt: "2026-03-23T00:00:00.000Z",
    });

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        {
          path: "@/features/saves/service",
          factory: () => ({
            default: class {
              getSaveState = getSaveStateMock;
              listSavedEntities = listSavedEntitiesMock;
              saveEntity = saveEntityMock;
              unsaveEntity = unsaveEntityMock;
              validateEntityType(entityType: string) {
                if (!["event", "thread", "message", "user"].includes(entityType)) {
                  throw new BadRequestError("Unsupported entity type");
                }
                return entityType;
              }
            },
          }),
        },
      ],
      activeRoutes: ["@app/server/routes/saves.route"],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: "/api/saves/user/user-2",
    });

    expect(response.status).toBe(200);
    expect(getSaveStateMock).toHaveBeenCalledWith("user-1", "user", "user-2");
    expect(response.body.data).toMatchObject({
      entityId: "user-2",
      entityType: "user",
      saved: true,
    });
  });

  it("rejects saving the current user's own profile", async () => {
    saveEntityMock.mockRejectedValue(
      new BadRequestError("You cannot save your own profile"),
    );

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        {
          path: "@/features/saves/service",
          factory: () => ({
            default: class {
              getSaveState = getSaveStateMock;
              listSavedEntities = listSavedEntitiesMock;
              saveEntity = saveEntityMock;
              unsaveEntity = unsaveEntityMock;
              validateEntityType(entityType: string) {
                if (!["event", "thread", "message", "user"].includes(entityType)) {
                  throw new BadRequestError("Unsupported entity type");
                }
                return entityType;
              }
            },
          }),
        },
      ],
      activeRoutes: ["@app/server/routes/saves.route"],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      method: "PUT",
      url: "/api/saves/user/user-1",
    });

    expect(response.status).toBe(400);
    expect(response.body.error).toMatchObject({
      message: "You cannot save your own profile",
      status: 400,
      type: "BadRequestError",
    });
  });
});
