# Socket Events Reference

This document describes the current Socket.IO contract implemented by the backend and consumed by the mobile client.

Machine-readable AsyncAPI version:

- `docs/socket-events.asyncapi.yaml`

It is a manual reference based on the current code in:

- `server/src/socket/index.ts`
- `server/src/socket/emitter.ts`
- `server/src/constants/index.ts`
- `client/lib/services/socket.dart`
- `client/lib/constants/socket_events.dart`

## Connection

- Transport: Socket.IO over WebSocket
- Transport path: `/socket.io/`
- Namespace: `/platform`
- Authentication:
  - mobile/native clients pass `token` as a query parameter
  - browser clients may authenticate via the session cookie
- Server-side auth middleware: `server/src/middlewares/socketUserParser.ts`

## Envelope conventions

Inbound acknowledgements generally use this shape:

```json
{ "data": true }
```

or:

```json
{ "data": { "...": "payload" } }
```

Errors generally use:

```json
{ "error": "Something went wrong" }
```

Server broadcasts emitted through `emitSocketEvent(...)` generally use:

```json
{ "data": { "...": "payload" } }
```

## Rooms

- Thread room format: `thread:{threadId}`
- Helper: `server/src/socket/rooms.ts`
- Clients join and leave thread rooms via `join:room` and `leave:room`

## Event status

- `implemented`: handled or emitted in production code today
- `partial`: constant exists, but server behavior is incomplete
- `reserved`: defined as a constant, but no current producer/consumer was found

## Client -> Server events

| Event | Status | Request payload | Ack payload | Notes |
| --- | --- | --- | --- | --- |
| `join:room` | implemented | `{ "room": "thread:<threadId>" }` | `{ "data": true }` or `{ "error": string }` | Validates thread rooms before joining. |
| `leave:room` | implemented | `{ "room": "thread:<threadId>" }` | `{ "data": true }` or `{ "error": string }` | Leaves a previously joined room. |
| `message:create` | implemented | `{ "threadId": string, "content": string \| { "text"?: string, "media"?: string[] }, "parentId"?: string }` | `{ "data": Message }` or `{ "error": string }` | Broadcasts `message:create` to the thread room after success. |
| `reaction:create` | implemented | `{ "contentId": string, "contentPath": "messages" \| "events" \| "threads", "reaction": string, "parentId"?: string }` | `{ "data": true }` or `{ "error": string }` | Broadcasts `reaction:create`. |
| `reaction:update` | implemented | `{ "contentId": string, "contentPath": "messages" \| "events" \| "threads", "reaction": string, "parentId"?: string }` | `{ "data": true }` or `{ "error": string }` | Broadcasts `reaction:update`. |
| `reaction:delete` | implemented | `{ "contentId": string, "contentPath": "messages" \| "events" \| "threads", "reaction": string, "parentId"?: string, "id"?: string }` | `{ "data": true }` or `{ "error": string }` | The server identifies the prior user reaction before deleting it. |
| `thread:create` | implemented | `{ "eventId": string, "content": string \| object, "parentId"?: string }` | `{ "data": true }` or `{ "error": string }` | Creates a thread and its first message, then broadcasts `thread:create`. |
| `explore` | implemented | `{ "filter": { "location": { "latitude": number, "longitude": number } } }` | `{ "data": true }` or `{ "error": string }` | Streams one or more `explore` broadcasts while scanning nearby events. |
| `message:update` | implemented | `{ "id": string, "content": string \| { "text"?: string, "media"?: string[] } }` | `{ "data": Message }` or `{ "error": string }` | Applies the same author and lock checks as the REST update flow, then broadcasts `message:update`. |
| `message:delete` | implemented | `{ "id": string }` | `{ "data": { "id": string, "threadId": string } }` or `{ "error": string }` | Applies the same author and lock checks as the REST delete flow, then broadcasts `message:delete`. |

## Server -> Client broadcasts

| Event | Status | Payload | Scope | Notes |
| --- | --- | --- | --- | --- |
| `event:create` | implemented | `{ "data": Event }` | namespace-wide | Emitted from REST event creation. |
| `event:update` | implemented | `{ "data": Event }` | namespace-wide | Emitted from REST updates, join/leave, verify-attendance, and Supabase media realtime updates. |
| `event:delete` | implemented | `{ "data": { "id": string } }` | namespace-wide | Emitted from REST delete. |
| `thread:create` | implemented | `{ "data": Thread }` or `{ "data": { ...Thread, "event": Event } }` | namespace-wide | Can be emitted by REST or by the socket thread-create flow. |
| `thread:update` | implemented | `{ "data": { "id": string, ...patch } }` | namespace-wide | Emitted from REST thread update. |
| `thread:delete` | implemented | `{ "data": { "id": string } }` | namespace-wide | Emitted from REST thread delete. |
| `thread:lock` | implemented | `{ "data": { "id": string, "lockHistory": any, "lockedBy": string } }` | `thread:{threadId}` room | Used by chat/thread screens to disable posting. |
| `thread:unlock` | implemented | `{ "data": { "id": string, "lockHistory": any, "unlockedBy": string } }` | `thread:{threadId}` room | Used by chat/thread screens to re-enable posting. |
| `message:create` | implemented | `{ "data": Message }` | `thread:{threadId}` room | Emitted by REST message creation and by socket message creation. |
| `message:update` | implemented | `{ "data": Message }` | `thread:{threadId}` room | Emitted by both REST and socket update flows. |
| `message:delete` | implemented | `{ "data": { "id": string, "threadId": string } }` | `thread:{threadId}` room | Emitted by both REST and socket delete flows. |
| `reaction:create` | implemented | `{ "data": { "id": string, "contentPath": string, "reaction": Reaction, "parentId"?: string, "threadId"?: string } }` | thread room when applicable, otherwise namespace-wide | Used by chat/thread reaction UIs. |
| `reaction:update` | implemented | `{ "data": { "id": string, "contentPath": string, "reaction": Reaction, "parentId"?: string, "threadId"?: string } }` | thread room when applicable, otherwise namespace-wide | Used by chat/thread reaction UIs. |
| `reaction:delete` | implemented | `{ "data": { "id": string, "contentPath": string, "reaction": Reaction, "parentId"?: string, "threadId"?: string } }` | thread room when applicable, otherwise namespace-wide | Used by chat/thread reaction UIs. |
| `explore` | implemented | `{ "data": ExploreSection }` | namespace-wide | Sent repeatedly during an explore request. |
| `user:update` | implemented | `{ "data": SafeUser }` | namespace-wide | Emitted from REST user profile updates. |

## Current client usage

The mobile client currently sends these socket events directly:

- `join:room`
- `leave:room`
- `message:create`
- `reaction:create`
- `reaction:update`
- `reaction:delete`

The mobile client currently listens for these broadcasts:

- `event:create`
- `event:update`
- `event:delete`
- `message:create`
- `message:update`
- `message:delete`
- `reaction:create`
- `reaction:update`
- `reaction:delete`
- `thread:lock`
- `thread:unlock`

No current client subscription was found for:

- `thread:create`
- `thread:update`
- `thread:delete`
- `explore`
- `user:update`

## Important implementation notes

- `message:update` and `message:delete` now work through both socket handlers and REST controllers, and both paths emit the same room-scoped broadcast event names.
- `event:update` is emitted not only for explicit event edits, but also after join/leave and verify-attendance mutations when the underlying event state changes.
- Some broadcasts are namespace-wide and some are room-scoped. Chat-style listeners should join the relevant `thread:{threadId}` room before relying on thread-specific updates.
- Event payload shapes are not yet enforced from a shared schema package. This file is a source-of-truth snapshot, not a generated spec.

## Recommended next step

If you want this to evolve beyond a manual reference, the next step is to formalize it as:

- an `AsyncAPI` document, or
- a typed internal socket contract module that generates docs from shared schemas

That would let REST and sockets follow the same documentation discipline.
