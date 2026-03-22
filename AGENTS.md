# Bhandara Agent Guide

This repository has three instruction layers:

- Root: shared repo rules and coordination
- `client/AGENTS.md`: Flutter client rules
- `server/AGENTS.md`: Node/Redis/backend container rules

When working in a subdirectory, apply the root guidance first, then the nearest local `AGENTS.md`.

## Repo Structure

- `client/`: Flutter application
- `server/`: Node.js/TypeScript backend
- `compose.yml`: local container orchestration
- `infra/`: ops-related configs

## General Rules

- Prefer targeted changes over broad refactors.
- Verify changes with the smallest relevant command first, then broader verification if needed.
- Do not assume Docker runtime paths match source paths; verify what the final image actually copies.
- Keep runtime assets explicit in Docker builds. Compiled JS alone is not enough when SQL, templates, or static assets are loaded at runtime.
- Organize code by feature or scope of responsibility, not by creating files mechanically. Prefer keeping related logic together when it serves one feature, and only split files when the boundary is meaningful.

## Current Project Patterns

- The backend supports two Redis integration modes:
  - Node backend/server/workers use TCP Redis config via explicit fields.
  - Supabase edge functions keep using Upstash REST env vars.
- The Node backend Redis usage is segmented by logical DB:
  - sessions -> DB 1
  - BullMQ -> DB 2
  - engagement/stats -> DB 3
  - rate limiting -> DB 4
  - general cache -> DB 5
  - activity/achievements -> DB 6
- Those Redis DB mappings are fixed in backend config code, not configurable by env.
- The mono backend container is intentionally separate from the split container setup.
- Mono container design:
  - single externally exposed port
  - internal nginx reverse proxy
  - `/` routes to backend API
  - `/redis/` routes to Redis Commander
- When adding mono-only tooling, keep it confined to `server/Dockerfile.mono`, `server/scripts/docker-mono-entrypoint.sh`, and mono compose wiring rather than the main app runtime.

## Compose Notes

- `server-mono` is behind the `mono` profile in `compose.yml`.
- Use `docker compose --profile mono up --build server-mono` for the mono container path.
- Avoid changing split services unless the task explicitly asks for them.

## Maintenance

- Keep these `AGENTS.md` files current when stable repo-specific patterns emerge.
- Update the closest relevant `AGENTS.md` when a new convention becomes intentional rather than incidental.
