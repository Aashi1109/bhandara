import type { Express, RequestHandler } from "express";
import { vi } from "vitest";
import { createAuthenticatedSession, createAuthenticatedUser } from "./http";

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
  "@/routes/auth.route",
  "@/routes/engagement.route",
  "@/routes/events.route",
  "@/routes/media.route",
  "@/routes/saves.route",
  "@/routes/search.route",
  "@/routes/tags.route",
  "@/routes/threads.route",
  "@/routes/users.route",
  "@/routes/webhooks.route",
];

export const createTestApp = async ({
  activeRoutes = [],
  authenticated = false,
  moduleMocks = [],
}: CreateTestAppOptions = {}): Promise<Express> => {
  vi.resetModules();

  vi.doMock("@/middlewares", async () => {
    const actual = await vi.importActual<Record<string, unknown>>("@/middlewares");

    const sessionParser: RequestHandler = authenticated
      ? (req, _res, next) => {
          (req as any).session = createAuthenticatedSession();
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
      const express = await import("express");
      return {
        default: express.Router(),
      };
    });
  }

  const { default: createServer } = await import("@/app");
  return createServer();
};
