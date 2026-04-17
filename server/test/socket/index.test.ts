import { beforeEach, describe, expect, it, vi } from 'vitest';

const {
  createJoinRoomMock,
  deleteExploreCursorMock,
  emitSocketEventMock,
  isThreadChainLockedMock,
  messageDeleteMock,
  messageGetByIdMock,
  messageUpdateMock,
  namespaceOnMock,
  namespaceToEmitMock,
  namespaceUseMock,
  ofMock,
  serverConstructorMock,
  setExploreCursorMock,
  setPlatformNamespaceMock,
  socketJoinMock,
  socketLeaveMock,
  socketOnMock,
} = vi.hoisted(() => ({
  createJoinRoomMock: vi.fn(),
  deleteExploreCursorMock: vi.fn(),
  emitSocketEventMock: vi.fn(),
  isThreadChainLockedMock: vi.fn(),
  messageDeleteMock: vi.fn(),
  messageGetByIdMock: vi.fn(),
  messageUpdateMock: vi.fn(),
  namespaceOnMock: vi.fn(),
  namespaceToEmitMock: vi.fn(),
  namespaceUseMock: vi.fn(),
  ofMock: vi.fn(),
  serverConstructorMock: vi.fn(),
  setExploreCursorMock: vi.fn(),
  setPlatformNamespaceMock: vi.fn(),
  socketJoinMock: vi.fn(),
  socketLeaveMock: vi.fn(),
  socketOnMock: vi.fn(),
}));

const namespaceMock = {
  emit: namespaceToEmitMock,
  on: namespaceOnMock,
  to: vi.fn(() => ({ emit: vi.fn() })),
  use: namespaceUseMock,
};

vi.mock('socket.io', () => ({
  Server: class {
    constructor(...args: unknown[]) {
      serverConstructorMock(...args);
      return {
        of: ofMock,
      };
    }
  },
}));

vi.mock('@/config', () => ({
  default: {
    corsOptions: {},
  },
}));

vi.mock('@/middlewares', () => ({
  requestContextMiddleware: vi.fn((_req, _res, next) => next()),
  socketUserParser: vi.fn((_socket, next) => next()),
}));

vi.mock('@/socket/emitter', () => ({
  emitSocketEvent: emitSocketEventMock,
  setPlatformNamespace: setPlatformNamespaceMock,
}));

vi.mock('@/features/reactions/constants', () => ({
  EAllowedReactionTables: {
    Event: 'events',
    Message: 'messages',
    Thread: 'threads',
  },
}));

vi.mock('@/features/users/service', () => ({
  default: class {},
  toUserMini: vi.fn((user) => user),
}));

vi.mock('@/features', () => ({
  EventService: class {
    getAll = vi.fn();
    getById = vi.fn();
  },
  MessageService: class {
    create = vi.fn();
    delete = messageDeleteMock;
    getById = messageGetByIdMock;
    update = messageUpdateMock;
  },
  ReactionService: class {
    create = vi.fn();
    deleteByQuery = vi.fn();
    getReactions = vi.fn();
    update = vi.fn();
  },
  ThreadService: class {
    create = vi.fn();
    getById = vi.fn();
    isThreadChainLocked = isThreadChainLockedMock;
  },
  ActivityService: class {},
  AchievementService: class {},
  buildExploreSections: vi.fn(() => []),
  buildMessageActivities: vi.fn(() => []),
  deleteExploreCursor: deleteExploreCursorMock,
  getExploreCursor: vi.fn(),
  getSafeUser: vi.fn((user) => user),
  setExploreCursor: setExploreCursorMock,
}));

vi.mock('@/features/activity/service', () => ({
  default: class {
    create = vi.fn();
  },
}));

vi.mock('@/features/achievements/service', () => ({
  default: class {
    trackActivity = vi.fn();
  },
}));

const getRegisteredSocketHandler = async (eventName: string) => {
  const { initializeSocket } = await import('@/socket/index');

  ofMock.mockReturnValue(namespaceMock);
  initializeSocket({} as any);

  const connectHandler = namespaceOnMock.mock.calls.find(([event]) => event === 'connect')?.[1];
  if (!connectHandler) {
    throw new Error('connect handler not registered');
  }

  const socket = {
    id: 'socket-1',
    join: socketJoinMock,
    leave: socketLeaveMock,
    on: socketOnMock,
    request: { user: { id: 'user-1' } },
  };

  await connectHandler(socket);

  const handler = socketOnMock.mock.calls.find(([event]) => event === eventName)?.[1];
  if (!handler) {
    throw new Error(`handler not registered for ${eventName}`);
  }

  return handler;
};

describe('socket message mutation handlers', () => {
  beforeEach(() => {
    createJoinRoomMock.mockReset();
    deleteExploreCursorMock.mockReset();
    emitSocketEventMock.mockReset();
    isThreadChainLockedMock.mockReset();
    messageDeleteMock.mockReset();
    messageGetByIdMock.mockReset();
    messageUpdateMock.mockReset();
    namespaceOnMock.mockReset();
    namespaceToEmitMock.mockReset();
    namespaceUseMock.mockReset();
    ofMock.mockReset();
    serverConstructorMock.mockReset();
    setExploreCursorMock.mockReset();
    setPlatformNamespaceMock.mockReset();
    socketJoinMock.mockReset();
    socketLeaveMock.mockReset();
    socketOnMock.mockReset();
  });

  it('updates a message via socket and emits the room-scoped broadcast payload', async () => {
    messageGetByIdMock.mockResolvedValue({
      id: 'message-1',
      threadId: 'thread-1',
      userId: 'user-1',
    });
    isThreadChainLockedMock.mockResolvedValue({ isLocked: false });
    messageUpdateMock.mockResolvedValue({
      content: { text: 'edited' },
      id: 'message-1',
      isEdited: true,
      threadId: 'thread-1',
      userId: 'user-1',
    });

    const handler = await getRegisteredSocketHandler('message:update');
    const ack = vi.fn();

    await handler({ content: { text: 'edited' }, id: 'message-1' }, ack);

    expect(messageUpdateMock).toHaveBeenCalledWith(
      'message-1',
      {
        content: { text: 'edited' },
        isEdited: true,
      },
      true,
    );
    expect(emitSocketEventMock).toHaveBeenCalledWith(
      'message:update',
      {
        data: {
          content: { text: 'edited' },
          id: 'message-1',
          isEdited: true,
          threadId: 'thread-1',
          userId: 'user-1',
        },
      },
      { room: 'thread:thread-1' },
    );
    expect(ack).toHaveBeenCalledWith({
      data: {
        content: { text: 'edited' },
        id: 'message-1',
        isEdited: true,
        threadId: 'thread-1',
        userId: 'user-1',
      },
    });
  });

  it('rejects socket message updates from non-authors', async () => {
    messageGetByIdMock.mockResolvedValue({
      id: 'message-1',
      threadId: 'thread-1',
      userId: 'author-1',
    });

    const handler = await getRegisteredSocketHandler('message:update');
    const ack = vi.fn();

    await handler({ content: { text: 'edited' }, id: 'message-1' }, ack);

    expect(messageUpdateMock).not.toHaveBeenCalled();
    expect(emitSocketEventMock).not.toHaveBeenCalled();
    expect(ack).toHaveBeenCalledWith({
      error: 'You can only edit your own messages',
    });
  });

  it('does not emit message:update when the socket edit only changes updatedAt', async () => {
    messageGetByIdMock.mockResolvedValue({
      content: { text: 'same text' },
      id: 'message-1',
      threadId: 'thread-1',
      updatedAt: '2026-04-05T10:00:00.000Z',
      userId: 'user-1',
    });
    isThreadChainLockedMock.mockResolvedValue({ isLocked: false });
    messageUpdateMock.mockResolvedValue({
      content: { text: 'same text' },
      id: 'message-1',
      isEdited: true,
      threadId: 'thread-1',
      updatedAt: '2026-04-05T10:05:00.000Z',
      userId: 'user-1',
    });

    const handler = await getRegisteredSocketHandler('message:update');
    const ack = vi.fn();

    await handler({ content: { text: 'same text' }, id: 'message-1' }, ack);

    expect(emitSocketEventMock).not.toHaveBeenCalled();
    expect(ack).toHaveBeenCalledWith({
      data: {
        content: { text: 'same text' },
        id: 'message-1',
        isEdited: true,
        threadId: 'thread-1',
        updatedAt: '2026-04-05T10:05:00.000Z',
        userId: 'user-1',
      },
    });
  });

  it('deletes a message via socket and emits the room-scoped delete payload', async () => {
    messageGetByIdMock.mockResolvedValue({
      id: 'message-1',
      threadId: 'thread-1',
      userId: 'user-1',
    });
    isThreadChainLockedMock.mockResolvedValue({ isLocked: false });
    messageDeleteMock.mockResolvedValue({
      id: 'message-1',
    });

    const handler = await getRegisteredSocketHandler('message:delete');
    const ack = vi.fn();

    await handler({ id: 'message-1' }, ack);

    expect(messageDeleteMock).toHaveBeenCalledWith('message-1');
    expect(emitSocketEventMock).toHaveBeenCalledWith(
      'message:delete',
      {
        data: { id: 'message-1', threadId: 'thread-1' },
      },
      { room: 'thread:thread-1' },
    );
    expect(ack).toHaveBeenCalledWith({
      data: { id: 'message-1', threadId: 'thread-1' },
    });
  });
});
