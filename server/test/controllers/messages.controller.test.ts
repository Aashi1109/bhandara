import type { Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const {
  activityCreateMock,
  emitSocketEventMock,
  messageCreateMock,
  messageDeleteMock,
  messageGetByIdMock,
  messageUpdateMock,
  threadGetByIdMock,
  trackActivityMock,
  trackViewMock,
} = vi.hoisted(() => ({
  activityCreateMock: vi.fn(),
  emitSocketEventMock: vi.fn(),
  messageCreateMock: vi.fn(),
  messageDeleteMock: vi.fn(),
  messageGetByIdMock: vi.fn(),
  messageUpdateMock: vi.fn(),
  threadGetByIdMock: vi.fn(),
  trackActivityMock: vi.fn(),
  trackViewMock: vi.fn(),
}));

vi.mock("@/features/messages/service", () => ({
  default: class {
    create = messageCreateMock;
    delete = messageDeleteMock;
    getById = messageGetByIdMock;
    getChildren = vi.fn();
    getAll = vi.fn();
    update = messageUpdateMock;
  },
}));

vi.mock("@/features/threads/service", () => ({
  default: class {
    getById = threadGetByIdMock;
    isThreadChainLocked = vi.fn().mockResolvedValue({ isLocked: false });
  },
}));

vi.mock("@/features/activity/service", () => ({
  default: class {
    create = activityCreateMock;
  },
}));

vi.mock("@/features/achievements/service", () => ({
  default: class {
    trackActivity = trackActivityMock;
  },
}));

vi.mock("@/features/engagement/service", () => ({
  default: class {
    trackView = trackViewMock;
  },
}));

vi.mock("@/socket/emitter", () => ({
  emitSocketEvent: emitSocketEventMock,
}));

describe("messages controller", () => {
  beforeEach(() => {
    activityCreateMock.mockReset();
    emitSocketEventMock.mockReset();
    messageCreateMock.mockReset();
    messageDeleteMock.mockReset();
    messageGetByIdMock.mockReset();
    messageUpdateMock.mockReset();
    threadGetByIdMock.mockReset();
    trackActivityMock.mockReset();
    trackViewMock.mockReset();
  });

  it("creates a public activity item plus a private owner update when someone else posts in a thread", async () => {
    threadGetByIdMock.mockResolvedValue({
      createdBy: "thread-owner-1",
      id: "thread-1",
    });
    messageCreateMock.mockResolvedValue({
      content: { text: "Dinner is ready" },
      id: "message-1",
      parentId: null,
      threadId: "thread-1",
      userId: "actor-1",
    });

    const { createMessage } = await import("@/features/messages/controller");
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      body: { content: { text: "Dinner is ready" } },
      params: { threadId: "thread-1" },
      user: { id: "actor-1" },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await createMessage(req as any, res);

    expect(activityCreateMock).toHaveBeenCalledTimes(2);
    expect(activityCreateMock).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        actorId: "actor-1",
        entityId: "message-1",
        type: "message.created",
        visibility: "public",
      }),
    );
    expect(activityCreateMock).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        actorId: "actor-1",
        entityId: "message-1",
        recipientId: "thread-owner-1",
        type: "message.created",
        visibility: "private",
      }),
    );
    expect(trackActivityMock).toHaveBeenCalledWith("actor-1", "message.created");
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      data: expect.objectContaining({ id: "message-1" }),
    });
  });

  it("rejects message updates from non-authors", async () => {
    messageGetByIdMock.mockResolvedValue({
      id: "message-1",
      threadId: "thread-1",
      userId: "author-1",
    });

    const { updateMessage } = await import("@/features/messages/controller");
    const req = {
      body: { content: { text: "edited" } },
      params: { messageId: "message-1" },
      user: { id: "intruder-1" },
    } as unknown as Request;
    const res = {
      json: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await expect(updateMessage(req as any, res)).rejects.toMatchObject({
      message: "You can only edit your own messages",
      status: 403,
    });
    expect(messageUpdateMock).not.toHaveBeenCalled();
  });

  it("rejects message deletes from non-authors", async () => {
    messageGetByIdMock.mockResolvedValue({
      id: "message-1",
      threadId: "thread-1",
      userId: "author-1",
    });

    const { deleteMessage } = await import("@/features/messages/controller");
    const req = {
      params: { messageId: "message-1" },
      user: { id: "intruder-1" },
    } as unknown as Request;
    const res = {
      json: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await expect(deleteMessage(req as any, res)).rejects.toMatchObject({
      message: "You can only delete your own messages",
      status: 403,
    });
    expect(messageDeleteMock).not.toHaveBeenCalled();
  });

  it("does not emit message:updated when only updatedAt changes", async () => {
    messageGetByIdMock.mockResolvedValue({
      content: { text: "same text" },
      id: "message-1",
      threadId: "thread-1",
      updatedAt: "2026-04-05T10:00:00.000Z",
      userId: "author-1",
    });
    messageUpdateMock.mockResolvedValue({
      content: { text: "same text" },
      id: "message-1",
      isEdited: true,
      threadId: "thread-1",
      updatedAt: "2026-04-05T10:05:00.000Z",
      userId: "author-1",
    });

    const { updateMessage } = await import("@/features/messages/controller");
    const req = {
      body: { content: { text: "same text" } },
      params: { messageId: "message-1" },
      user: { id: "author-1" },
    } as unknown as Request;
    const res = {
      json: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await updateMessage(req as any, res);

    expect(messageUpdateMock).toHaveBeenCalledWith(
      "message-1",
      {
        content: { text: "same text" },
        isEdited: true,
      },
      true,
    );
    expect(emitSocketEventMock).not.toHaveBeenCalled();
  });
});
