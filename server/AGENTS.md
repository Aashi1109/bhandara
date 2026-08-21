# Server Agent Guide

Apply this file together with the root [AGENTS.md](/Users/ashishpal/Desktop/coding/projects/zentry/AGENTS.md).

## Stack

- Node.js
- TypeScript
- Express
- Sequelize
- pg-boss workers (Postgres-backed job queues)
- Redis via `ioredis`

## Commands

- Install: `pnpm install`
- Build: `pnpm build`
- Test: `pnpm test`
- Lint: `pnpm lint`

Prefer running `pnpm build` and `pnpm test` after backend changes unless the task is clearly narrower.

## Redis Conventions

- Main Node backend uses explicit TCP Redis fields:
  - `REDIS_HOST`
  - `REDIS_PORT`
  - `REDIS_PASSWORD`
  - `REDIS_DB`
  - `REDIS_TLS`
- Keep worker and shared Redis connection-manager config in the same shape.
- Use named Redis connection-manager entries instead of one shared DB for everything.
- Current Redis DB layout:
  - sessions -> DB 1
  - bull -> DB 2
  - analytics -> DB 3
  - rate_limit -> DB 4
  - cache -> DB 5
  - activity -> DB 6
- Keep those DB indexes hardcoded in backend config unless there is a deliberate architecture change.
- Do not reintroduce `@upstash/redis` into the main Node backend unless explicitly requested.
- Supabase edge functions are separate and may continue using:
  - `UPSTASH_REDIS_REST_URL`
  - `UPSTASH_REDIS_REST_TOKEN`

## Docker Conventions

- `server/Dockerfile` is the normal backend image.
- `server/Dockerfile.mono` is the all-in-one image for:
  - Redis
  - API server
  - worker
  - nginx
  - Redis Commander
- Mono image runtime paths are based on copied build output, not source layout.
- If runtime code reads non-TS assets, copy them explicitly into the final image.
  - Current known requirement: `src/migrations` must be copied so bootstrap SQL exists at `/app/src/migrations/bootstrap`.
- Mono deploys must pin a target platform to avoid local arm64 builds being reused on amd64 hosts.
  - Current default: `linux/amd64`
  - Override with `SERVER_MONO_PLATFORM` only when the host architecture is intentionally different.

## Mono Container Rules

- External access is single-port only.
- nginx is the public entrypoint inside mono.
- Route map:
  - `/` -> backend API
  - `/redis/` -> Redis Commander
- Backend app runs internally on `APP_PORT`.
- Redis Commander runs internally on `REDIS_COMMANDER_PORT`.

## Caution Areas

- Startup failures in mono often come from missing runtime assets or wrong built-path assumptions.
- When debugging mono container exits, log the actual startup exception before changing behavior.
- Avoid leaving debug `console.log` calls in worker startup code.
