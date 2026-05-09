import { describe, expect, it, vi } from "vitest";
import { createTestApp } from "../helpers/app";
import { authHeaders, invokeApp } from "../helpers/http";

const getThreadsMock = vi.fn();
const getThreadMock = vi.fn();

const buildThreadsModuleMock = () => ({
  createThread: vi.fn(),
  deleteThread: vi.fn(),
  getThread: getThreadMock,
  getThreads: getThreadsMock,
  lockThread: vi.fn(),
  unlockThread: vi.fn(),
  updateThread: vi.fn(),
});

const buildMessagesModuleMock = () => ({
  createMessage: vi.fn(),
  deleteMessage: vi.fn(),
  getChildMessages: vi.fn(),
  getMessageById: vi.fn(),
  getMessages: vi.fn(),
  updateMessage: vi.fn(),
});

describe("threads routes", () => {
  it("returns a thread list envelope", async () => {
    getThreadsMock.mockImplementation(async (_req, res) =>
      res.status(200).json({
        data: {
          items: [{ id: "thread-1", title: "Logistics" }],
          pagination: { hasNext: false, limit: 20, next: null, total: 1 },
        },
      }),
    );

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        { factory: () => buildThreadsModuleMock(), path: "@/features/threads/controller" },
        { factory: () => buildMessagesModuleMock(), path: "@/features/messages/controller" },
      ],
      activeRoutes: ["@app/server/routes/threads.route"],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: "/api/threads",
    });

    expect(response.status).toBe(200);
    expect(response.body.data.items).toEqual([{ id: "thread-1", title: "Logistics" }]);
  });

  it("returns thread detail with representative fields", async () => {
    getThreadMock.mockImplementation(async (_req, res) =>
      res.status(200).json({
        data: {
          eventId: "event-1",
          id: "thread-1",
          messages: [{ id: "message-1", text: "See you there" }],
          title: "Logistics",
        },
      }),
    );

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        { factory: () => buildThreadsModuleMock(), path: "@/features/threads/controller" },
        { factory: () => buildMessagesModuleMock(), path: "@/features/messages/controller" },
      ],
      activeRoutes: ["@app/server/routes/threads.route"],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: "/api/threads/thread-1",
    });

    expect(response.status).toBe(200);
    expect(response.body.data).toMatchObject({
      eventId: "event-1",
      id: "thread-1",
      title: "Logistics",
    });
    expect(response.body.data.messages).toEqual([{ id: "message-1", text: "See you there" }]);
  });

  it("requires authentication", async () => {
    const app = await createTestApp({
      moduleMocks: [
        { factory: () => buildThreadsModuleMock(), path: "@/features/threads/controller" },
        { factory: () => buildMessagesModuleMock(), path: "@/features/messages/controller" },
      ],
      activeRoutes: ["@app/server/routes/threads.route"],
    });

    const response = await invokeApp(app, {
      url: "/api/threads",
    });

    expect(response.status).toBe(401);
    expect(response.body.data).toBeNull();
  });
});
