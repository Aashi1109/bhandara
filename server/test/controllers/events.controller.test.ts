import type { Request, Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const {
  activityCreateMock,
  emitSocketEventMock,
  getAllMock,
  getByIdMock,
  getEventDataMock,
  getMarkersMock,
  updateMock,
  joinLeaveEventMock,
  trackActivityMock,
  toEventSummaryMock,
  verifyEventMock,
} = vi.hoisted(() => ({
  activityCreateMock: vi.fn(),
  emitSocketEventMock: vi.fn(),
  getAllMock: vi.fn(),
  getByIdMock: vi.fn(),
  getEventDataMock: vi.fn(),
  getMarkersMock: vi.fn(),
  updateMock: vi.fn(),
  joinLeaveEventMock: vi.fn(),
  trackActivityMock: vi.fn(),
  toEventSummaryMock: vi.fn((event) => event),
  verifyEventMock: vi.fn(),
}));

vi.mock('@/features/events/service', () => ({
  default: class {
    getAll = getAllMock;
    getById = getByIdMock;
    getEventData = getEventDataMock;
    getMarkers = getMarkersMock;
    update = updateMock;
    joinLeaveEvent = joinLeaveEventMock;
    verifyEvent = verifyEventMock;
  },
  toEventSummary: toEventSummaryMock,
}));

vi.mock('@/features/tags/service', () => ({
  default: class {},
}));

vi.mock('@/features/activity/service', () => ({
  default: class {
    create = activityCreateMock;
  },
}));

vi.mock('@/features/achievements/service', () => ({
  default: class {
    trackActivity = trackActivityMock;
  },
}));

vi.mock('@/features/engagement/service', () => ({
  default: class {},
}));

vi.mock('@/socket/emitter', () => ({
  emitSocketEvent: emitSocketEventMock,
}));

describe('events controller', () => {
  beforeEach(() => {
    activityCreateMock.mockReset();
    emitSocketEventMock.mockReset();
    getAllMock.mockReset();
    getByIdMock.mockReset();
    getEventDataMock.mockReset();
    getMarkersMock.mockReset();
    updateMock.mockReset();
    joinLeaveEventMock.mockReset();
    trackActivityMock.mockReset();
    toEventSummaryMock.mockClear();
    verifyEventMock.mockReset();
    activityCreateMock.mockResolvedValue({ recipientId: null });
    vi.useRealTimers();
  });

  it('parses explore filters and forwards them to EventService.getAll', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-03-23T10:30:00.000Z'));
    getAllMock.mockResolvedValue({
      items: [],
      pagination: { hasNext: false, limit: 20, next: null, total: 0 },
    });

    const { getEvents } = await import('@/features/events/controller');
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      pagination: { limit: 20, next: null, sortBy: 'createdAt', sortOrder: 'desc' },
      query: {
        createdBy: 'user-1',
        status: 'ongoing,upcoming',
        type: 'organized',
        latitude: '18.5204',
        longitude: '73.8567',
        radiusKm: '250',
        tagIds: 'tag-1,tag-2',
        datePreset: 'this_week',
      },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await getEvents(req as any, res);

    expect(getAllMock).toHaveBeenCalledTimes(1);
    const [filtersArg, paginationArg] = getAllMock.mock.calls[0];
    expect(filtersArg).toMatchObject({
      createdBy: 'user-1',
      statuses: ['ongoing', 'upcoming'],
      types: ['organized'],
      latitude: 18.5204,
      longitude: 73.8567,
      radiusKm: 250,
      tagIds: ['tag-1', 'tag-2'],
    });
    expect(filtersArg.startDate).toBeInstanceOf(Date);
    expect(filtersArg.endDate).toBeInstanceOf(Date);
    expect(filtersArg.startDate.getTime()).toBeLessThan(filtersArg.endDate.getTime());
    expect(paginationArg).toEqual({
      limit: 20,
      next: null,
      sortBy: 'createdAt',
      sortOrder: 'desc',
    });
    expect(status).toHaveBeenCalledWith(200);
  });

  it('rejects invalid filter values', async () => {
    const { getEvents } = await import('@/features/events/controller');
    const req = {
      pagination: { limit: 20, next: null, sortBy: 'createdAt', sortOrder: 'desc' },
      query: { type: 'conference' },
    } as unknown as Request;
    const res = {
      json: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await expect(getEvents(req as any, res)).rejects.toThrow(
      'Invalid event type filter',
    );
  });

  it('forwards flat marker requests to EventService.getMarkers', async () => {
    getMarkersMock.mockResolvedValue({
      mode: 'flat',
      items: [{ id: 'event-1', name: 'Community Dinner', latitude: 18.52, longitude: 73.85 }],
    });

    const { getEventMarkers } = await import('@/features/events/controller');
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      query: {
        status: 'upcoming',
        latitude: '18.5204',
        longitude: '73.8567',
        radiusKm: '25',
        flat: 'true',
      },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await getEventMarkers(req as any, res);

    expect(getMarkersMock).toHaveBeenCalledTimes(1);
    expect(getMarkersMock).toHaveBeenCalledWith(
      expect.objectContaining({
        statuses: ['upcoming'],
        latitude: 18.5204,
        longitude: 73.8567,
        radiusKm: 25,
      }),
      expect.objectContaining({
        flat: true,
        tiles: undefined,
        zoom: undefined,
      }),
    );
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      data: {
        mode: 'flat',
        items: [{ id: 'event-1', name: 'Community Dinner', latitude: 18.52, longitude: 73.85 }],
      },
    });
  });

  it('emits event:update after join/leave mutations', async () => {
    const previousEvent = {
      id: 'event-1',
      visibility: 'public',
      participants: [],
    };
    const updatedEvent = {
      id: 'event-1',
      visibility: 'public',
      participants: [{ status: 'confirmed', user: 'user-1' }],
    };
    getByIdMock.mockResolvedValue({ createdBy: 'owner-1', id: 'event-1' });
    joinLeaveEventMock.mockResolvedValue('Successfully joined the event');
    getEventDataMock
      .mockResolvedValueOnce(previousEvent)
      .mockResolvedValueOnce(updatedEvent);

    const { eventJoinLeaveHandler } = await import('@/features/events/controller');
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      params: { action: 'join', eventId: 'event-1' },
      user: { id: 'user-1' },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await eventJoinLeaveHandler(req as any, res);

    expect(joinLeaveEventMock).toHaveBeenCalledWith('user-1', 'event-1', 'join');
    expect(emitSocketEventMock).toHaveBeenCalledWith('event:update', {
      data: updatedEvent,
    });
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({ data: updatedEvent });
  });

  it('does not broadcast join/leave mutations on private events', async () => {
    const previousEvent = { id: 'event-1', visibility: 'private', participants: [] };
    const updatedEvent = {
      id: 'event-1',
      visibility: 'private',
      participants: [{ status: 'confirmed', user: 'user-1' }],
    };
    getByIdMock.mockResolvedValue({ createdBy: 'owner-1', id: 'event-1' });
    joinLeaveEventMock.mockResolvedValue('Successfully joined the event');
    getEventDataMock.mockResolvedValueOnce(previousEvent).mockResolvedValueOnce(updatedEvent);

    const { eventJoinLeaveHandler } = await import('@/features/events/controller');
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      params: { action: 'join', eventId: 'event-1' },
      user: { id: 'user-1' },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await eventJoinLeaveHandler(req as any, res);

    // The socket broadcast is unscoped, so a private event must never reach it.
    expect(emitSocketEventMock).not.toHaveBeenCalledWith('event:update', { data: updatedEvent });
    // The requester still gets the payload over REST.
    expect(json).toHaveBeenCalledWith({ data: updatedEvent });
  });

  it('emits event:update after event verification', async () => {
    const previousEvent = {
      id: 'event-1',
      visibility: 'public',
      verifiers: [],
    };
    const updatedEvent = {
      id: 'event-1',
      visibility: 'public',
      verifiers: [{ user: 'user-1' }],
    };
    verifyEventMock.mockResolvedValue(true);
    getEventDataMock
      .mockResolvedValueOnce(previousEvent)
      .mockResolvedValueOnce(updatedEvent);

    const { verifyEvent } = await import('@/features/events/controller');
    const status = vi.fn().mockReturnThis();
    const json = vi.fn();
    const req = {
      body: { currentCoordinates: { latitude: 18.52, longitude: 73.85 } },
      params: { eventId: 'event-1' },
      user: { id: 'user-1' },
    } as unknown as Request;
    const res = { json, status } as unknown as Response;

    await verifyEvent(req as any, res);

    expect(verifyEventMock).toHaveBeenCalledWith('user-1', 'event-1', {
      latitude: 18.52,
      longitude: 73.85,
    });
    expect(emitSocketEventMock).toHaveBeenCalledWith('event:update', {
      data: updatedEvent,
    });
    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({ data: updatedEvent });
  });

  it('does not emit event:update when updateEvent makes no meaningful change', async () => {
    const existingEvent = {
      createdBy: 'owner-1',
      id: 'event-1',
    };
    const hydratedEvent = {
      id: 'event-1',
      name: 'Community Dinner',
      updatedAt: '2026-04-05T10:00:00.000Z',
    };
    const updatedEvent = {
      id: 'event-1',
      name: 'Community Dinner',
      updatedAt: '2026-04-05T10:05:00.000Z',
    };

    getByIdMock.mockResolvedValue(existingEvent);
    getEventDataMock.mockResolvedValue(hydratedEvent);
    updateMock.mockResolvedValue(updatedEvent);

    const { updateEvent } = await import('@/features/events/controller');
    const req = {
      body: { name: 'Community Dinner' },
      params: { eventId: 'event-1' },
      user: { id: 'owner-1' },
    } as unknown as Request;
    const res = {
      json: vi.fn(),
      status: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await updateEvent(req as any, res);

    expect(updateMock).toHaveBeenCalledWith({
      data: { name: 'Community Dinner' },
      existing: existingEvent,
      populate: true,
    });
    expect(emitSocketEventMock).not.toHaveBeenCalled();
  });
});
