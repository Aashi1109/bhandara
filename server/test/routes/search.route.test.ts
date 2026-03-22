import { beforeEach, describe, expect, it, vi } from "vitest";
import { createTestApp } from "../helpers/app";
import { invokeApp } from "../helpers/http";

const searchMock = vi.fn();
const getSuggestionsMock = vi.fn();

describe("search routes", () => {
  beforeEach(() => {
    searchMock.mockReset();
    getSuggestionsMock.mockReset();
  });

  it("returns search results with the expected envelope", async () => {
    searchMock.mockResolvedValue({
      items: [{ id: "event-1", title: "Community Dinner", type: "event" }],
      pagination: { hasNext: false, limit: 20, next: null, total: 1 },
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: "@/features/search/service",
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ["@/routes/search.route"],
    });

    const response = await invokeApp(app, {
      url: "/api/search?query=dinner",
    });

    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({
      items: [{ id: "event-1", title: "Community Dinner", type: "event" }],
      pagination: { hasNext: false, limit: 20, next: null, total: 1 },
    });
  });

  it("rejects too-short queries", async () => {
    const app = await createTestApp({
      moduleMocks: [
        {
          path: "@/features/search/service",
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ["@/routes/search.route"],
    });

    const response = await invokeApp(app, {
      url: "/api/search?query=a",
    });

    expect(response.status).toBe(400);
    expect(response.body.data).toBeNull();
    expect(response.body.error.message).toBe("Invalid search parameters");
  });

  it("returns empty search results cleanly", async () => {
    searchMock.mockResolvedValue({
      items: [],
      pagination: { hasNext: false, limit: 20, next: null, total: 0 },
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: "@/features/search/service",
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ["@/routes/search.route"],
    });

    const response = await invokeApp(app, {
      url: "/api/search?query=zzzz",
    });

    expect(response.status).toBe(200);
    expect(response.body.data.items).toEqual([]);
    expect(response.body.data.pagination.total).toBe(0);
  });
});
