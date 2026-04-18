import { describe, expect, it, vi } from 'vitest';
import { createTestApp } from '../helpers/app';
import { authHeaders, invokeApp } from '../helpers/http';

const getEventsMock = vi.fn();
const getEventByIdMock = vi.fn();

const buildEventsModuleMock = () => ({
  createEvent: vi.fn(),
  deleteEvent: vi.fn(),
  deleteEventMedia: vi.fn(),
  deleteEventTag: vi.fn(),
  disassociateMediaFromEvent: vi.fn(),
  eventJoinLeaveHandler: vi.fn(),
  getEventById: getEventByIdMock,
  getEventMarkers: vi.fn(),
  getEvents: getEventsMock,
  getEventThreads: vi.fn(),
  updateEvent: vi.fn(),
  verifyEvent: vi.fn(),
});

const buildThreadsModuleMock = () => ({
  createThread: vi.fn(),
  deleteThread: vi.fn(),
  getThread: vi.fn(),
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

describe('events routes', () => {
  it('returns paginated events from GET /events', async () => {
    getEventsMock.mockImplementation(async (_req, res) =>
      res.status(200).json({
        data: {
          items: [{ id: 'event-1', name: 'Community Dinner' }],
          pagination: { hasNext: false, limit: 20, next: null, total: 1 },
        },
      }),
    );

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        { factory: () => buildEventsModuleMock(), path: '@/src/features/events/controller' },
        { factory: () => buildThreadsModuleMock(), path: '@/src/features/threads/controller' },
        { factory: () => buildMessagesModuleMock(), path: '@/src/features/messages/controller' },
      ],
      activeRoutes: ['@/app/server/routes/events.route'],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: '/api/events',
    });

    expect(response.status).toBe(200);
    expect(response.body.data.items).toEqual([{ id: 'event-1', name: 'Community Dinner' }]);
    expect(response.body.data.pagination).toMatchObject({
      hasNext: false,
      limit: 20,
      next: null,
      total: 1,
    });
  });

  it('returns event detail from GET /events/:eventId', async () => {
    getEventByIdMock.mockImplementation(async (_req, res) =>
      res.status(200).json({
        data: { id: 'event-1', name: 'Community Dinner', status: 'published' },
      }),
    );

    const app = await createTestApp({
      authenticated: true,
      moduleMocks: [
        { factory: () => buildEventsModuleMock(), path: '@/src/features/events/controller' },
        { factory: () => buildThreadsModuleMock(), path: '@/src/features/threads/controller' },
        { factory: () => buildMessagesModuleMock(), path: '@/src/features/messages/controller' },
      ],
      activeRoutes: ['@/app/server/routes/events.route'],
    });

    const response = await invokeApp(app, {
      headers: authHeaders,
      url: '/api/events/event-1',
    });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      data: { id: 'event-1', name: 'Community Dinner', status: 'published' },
    });
  });

  it('rejects unauthenticated access', async () => {
    const app = await createTestApp({
      moduleMocks: [
        { factory: () => buildEventsModuleMock(), path: '@/src/features/events/controller' },
        { factory: () => buildThreadsModuleMock(), path: '@/src/features/threads/controller' },
        { factory: () => buildMessagesModuleMock(), path: '@/src/features/messages/controller' },
      ],
      activeRoutes: ['@/app/server/routes/events.route'],
    });

    const response = await invokeApp(app, {
      url: '/api/events',
    });

    expect(response.status).toBe(401);
    expect(response.body.data).toBeNull();
  });
});
