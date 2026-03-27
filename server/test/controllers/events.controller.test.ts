import type { Request, Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { getAllMock } = vi.hoisted(() => ({
  getAllMock: vi.fn(),
}));

vi.mock('@/features/events/service', () => ({
  default: class {
    getAll = getAllMock;
  },
}));

vi.mock('@/features/tags/service', () => ({
  default: class {},
}));

vi.mock('@/features/activity/service', () => ({
  default: class {},
}));

vi.mock('@/features/achievements/service', () => ({
  default: class {},
}));

vi.mock('@/features/engagement/service', () => ({
  default: class {},
}));

describe('events controller', () => {
  beforeEach(() => {
    getAllMock.mockReset();
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
});
