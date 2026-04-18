import type { Express, RequestHandler } from 'express';
import { vi } from 'vitest';
import { createAuthenticatedSession, createAuthenticatedUser } from './http';

type ModuleMock = {
  factory: () => unknown | Promise<unknown>;
  path: string;
};

type CreateTestAppOptions = {
  activeRoutes?: string[];
  authenticated?: boolean;
  moduleMocks?: ModuleMock[];
};

const ROUTE_MODULES = [
  '@/app/server/routes/auth.route',
  '@/app/server/routes/engagement.route',
  '@/app/server/routes/events.route',
  '@/app/server/routes/media.route',
  '@/app/server/routes/saves.route',
  '@/app/server/routes/search.route',
  '@/app/server/routes/tags.route',
  '@/app/server/routes/threads.route',
  '@/app/server/routes/users.route',
  '@/app/server/routes/webhooks.route',
];

export const createTestApp = async ({
  activeRoutes = [],
  authenticated = false,
  moduleMocks = [],
}: CreateTestAppOptions = {}): Promise<Express> => {
  vi.resetModules();

  vi.doMock('@/app/server/middlewares', async () => {
    const actual = await vi.importActual<Record<string, unknown>>('@/app/server/middlewares');

    const sessionParser: RequestHandler = authenticated
      ? (req, _res, next) => {
          (req as any).session = createAuthenticatedSession();
          (req as any).signedCookies = { bh_session: 'test-session' };
          next();
        }
      : (actual.sessionParser as RequestHandler);

    const userParser: RequestHandler = authenticated
      ? (req, _res, next) => {
          (req as any).user = createAuthenticatedUser();
          next();
        }
      : (actual.userParser as RequestHandler);

    return {
      ...actual,
      sessionParser,
      userParser,
    };
  });

  for (const { path, factory } of moduleMocks) {
    vi.doMock(path, factory);
  }

  for (const routeModule of ROUTE_MODULES) {
    if (activeRoutes.includes(routeModule)) continue;
    vi.doMock(routeModule, async () => {
      const express = await import('express');
      return {
        default: express.Router(),
      };
    });
  }

  const { createServer } = await import('../../app/server');
  return createServer();
};
