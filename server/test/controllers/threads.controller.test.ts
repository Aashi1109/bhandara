import type { Request, Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const {
  emitSocketEventMock,
  getByIdMock,
  updateMock,
} = vi.hoisted(() => ({
  emitSocketEventMock: vi.fn(),
  getByIdMock: vi.fn(),
  updateMock: vi.fn(),
}));

vi.mock('@/features/threads/service', () => ({
  default: class {
    create = vi.fn();
    delete = vi.fn();
    getAll = vi.fn();
    getById = getByIdMock;
    isThreadChainLocked = vi.fn();
    lockThread = vi.fn();
    unlockThread = vi.fn();
    update = updateMock;
  },
}));

vi.mock('@/features/events/service', () => ({
  default: class {},
}));

vi.mock('@/features/messages/service', () => ({
  default: class {},
}));

vi.mock('@/features/engagement/service', () => ({
  default: class {},
}));

vi.mock('@/socket/emitter', () => ({
  emitSocketEvent: emitSocketEventMock,
}));

describe('threads controller', () => {
  beforeEach(() => {
    emitSocketEventMock.mockReset();
    getByIdMock.mockReset();
    updateMock.mockReset();
  });

  it('does not emit thread:updated when only updatedAt changes', async () => {
    getByIdMock.mockResolvedValue({
      id: 'thread-1',
      title: 'General',
      updatedAt: '2026-04-05T10:00:00.000Z',
    });
    updateMock.mockResolvedValue({
      id: 'thread-1',
      title: 'General',
      updatedAt: '2026-04-05T10:05:00.000Z',
    });

    const { updateThread } = await import('@/features/threads/controller');
    const req = {
      body: { title: 'General' },
      params: { threadId: 'thread-1' },
      user: { id: 'user-1' },
    } as unknown as Request;
    const res = {
      json: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await updateThread(req as any, res);

    expect(updateMock).toHaveBeenCalledWith('thread-1', { title: 'General' }, true);
    expect(emitSocketEventMock).not.toHaveBeenCalled();
  });
});
