import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createTestApp } from '../helpers/app';
import { invokeApp } from '../helpers/http';

const searchMock = vi.fn();
const getSuggestionsMock = vi.fn();

describe('search routes', () => {
  beforeEach(() => {
    searchMock.mockReset();
    getSuggestionsMock.mockReset();
  });

  it('returns search results with the expected envelope', async () => {
    searchMock.mockResolvedValue({
      items: [
        {
          id: 'event-1',
          title: 'Community Dinner',
          type: 'event',
          metadata: {
            status: 'upcoming',
            createdAt: '2026-03-27T10:00:00.000Z',
          },
        },
      ],
      pagination: { hasNext: false, limit: 20, next: null, total: 1 },
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features/search/service',
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ['@app/server/routes/search.route'],
    });

    const response = await invokeApp(app, {
      url: '/api/search?query=dinner&status=ongoing,upcoming&type=organized&tagIds=tag-1,tag-2&latitude=18.52&longitude=73.85&radiusKm=50&datePreset=this_week',
    });

    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({
      items: [
        {
          id: 'event-1',
          title: 'Community Dinner',
          type: 'event',
          metadata: {
            status: 'upcoming',
            createdAt: '2026-03-27T10:00:00.000Z',
          },
        },
      ],
      pagination: { hasNext: false, limit: 20, next: null, total: 1 },
    });
    expect(searchMock).toHaveBeenCalledTimes(1);
    expect(searchMock.mock.calls[0]?.[0]).toBe('dinner');
    expect(searchMock.mock.calls[0]?.[1]).toMatchObject({
      eventStatus: ['ongoing', 'upcoming'],
      eventType: ['organized'],
      location: {
        latitude: 18.52,
        longitude: 73.85,
        radius: 50,
      },
      tags: ['tag-1', 'tag-2'],
      limit: 20,
      next: null,
    });
    expect(searchMock.mock.calls[0]?.[1].startDate).toBeInstanceOf(Date);
    expect(searchMock.mock.calls[0]?.[1].endDate).toBeInstanceOf(Date);
  });

  it('rejects too-short queries', async () => {
    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features/search/service',
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ['@app/server/routes/search.route'],
    });

    const response = await invokeApp(app, {
      url: '/api/search?query=a',
    });

    expect(response.status).toBe(400);
    expect(response.body.data).toBeNull();
    expect(response.body.error.message).toBe('Invalid search parameters');
  });

  it('returns empty search results cleanly', async () => {
    searchMock.mockResolvedValue({
      items: [],
      pagination: { hasNext: false, limit: 20, next: null, total: 0 },
    });

    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features/search/service',
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ['@app/server/routes/search.route'],
    });

    const response = await invokeApp(app, {
      url: '/api/search?query=zzzz',
    });

    expect(response.status).toBe(200);
    expect(response.body.data.items).toEqual([]);
    expect(response.body.data.pagination.total).toBe(0);
  });

  it('rejects invalid event filters', async () => {
    const app = await createTestApp({
      moduleMocks: [
        {
          path: '@/features/search/service',
          factory: () => ({
            default: {
              getSuggestions: getSuggestionsMock,
              search: searchMock,
            },
          }),
        },
      ],
      activeRoutes: ['@app/server/routes/search.route'],
    });

    const response = await invokeApp(app, {
      url: '/api/search?query=dinner&type=conference',
    });

    expect(response.status).toBe(400);
    expect(response.body.error.message).toBe('Invalid event type filter');
  });
});
