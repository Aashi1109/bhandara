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
| `message:created` | implemented | `{ "threadId": string, "content": string \| { "text"?: string, "media"?: string[] }, "parentId"?: string }` | `{ "data": Message }` or `{ "error": string }` | Broadcasts `message:created` to the thread room after success. |
| `reaction:created` | implemented | `{ "contentId": string, "contentPath": "messages" \| "events" \| "threads", "reaction": string, "parentId"?: string }` | `{ "data": true }` or `{ "error": string }` | Broadcasts `reaction:created`. |
| `reaction:updated` | implemented | `{ "contentId": string, "contentPath": "messages" \| "events" \| "threads", "reaction": string, "parentId"?: string }` | `{ "data": true }` or `{ "error": string }` | Broadcasts `reaction:updated`. |
| `reaction:deleted` | implemented | `{ "contentId": string, "contentPath": "messages" \| "events" \| "threads", "reaction": string, "parentId"?: string, "id"?: string }` | `{ "data": true }` or `{ "error": string }` | The server identifies the prior user reaction before deleting it. |
| `thread:created` | implemented | `{ "eventId": string, "content": string \| object, "parentId"?: string }` | `{ "data": true }` or `{ "error": string }` | Creates a thread and its first message, then broadcasts `thread:created`. |
| `explore` | implemented | `{ "filter": { "location": { "latitude": number, "longitude": number } } }` | `{ "data": true }` or `{ "error": string }` | Streams one or more `explore` broadcasts while scanning nearby events. |
| `message:updated` | implemented | `{ "id": string, "content": string \| { "text"?: string, "media"?: string[] } }` | `{ "data": Message }` or `{ "error": string }` | Applies the same author and lock checks as the REST update flow, then broadcasts `message:updated`. |
| `message:deleted` | implemented | `{ "id": string }` | `{ "data": { "id": string, "threadId": string } }` or `{ "error": string }` | Applies the same author and lock checks as the REST delete flow, then broadcasts `message:deleted`. |

## Server -> Client broadcasts

| Event | Status | Payload | Scope | Notes |
| --- | --- | --- | --- | --- |
| `event:created` | implemented | `{ "data": Event }` | namespace-wide | Emitted from REST event creation. |
| `event:updated` | implemented | `{ "data": Event }` | namespace-wide | Emitted from REST updates, join/leave, verify-attendance, and Supabase media realtime updates. |
| `event:deleted` | implemented | `{ "data": { "id": string } }` | namespace-wide | Emitted from REST delete. |
| `thread:created` | implemented | `{ "data": Thread }` or `{ "data": { ...Thread, "event": Event } }` | namespace-wide | Can be emitted by REST or by the socket thread-create flow. |
| `thread:updated` | implemented | `{ "data": { "id": string, ...patch } }` | namespace-wide | Emitted from REST thread update. |
| `thread:deleted` | implemented | `{ "data": { "id": string } }` | namespace-wide | Emitted from REST thread delete. |
| `thread:locked` | implemented | `{ "data": { "id": string, "lockHistory": any, "lockedBy": string } }` | `thread:{threadId}` room | Used by chat/thread screens to disable posting. |
| `thread:unlocked` | implemented | `{ "data": { "id": string, "lockHistory": any, "unlockedBy": string } }` | `thread:{threadId}` room | Used by chat/thread screens to re-enable posting. |
| `message:created` | implemented | `{ "data": Message }` | `thread:{threadId}` room | Emitted by REST message creation and by socket message creation. |
| `message:updated` | implemented | `{ "data": Message }` | `thread:{threadId}` room | Emitted by both REST and socket update flows. |
| `message:deleted` | implemented | `{ "data": { "id": string, "threadId": string } }` | `thread:{threadId}` room | Emitted by both REST and socket delete flows. |
| `reaction:created` | implemented | `{ "data": { "id": string, "contentPath": string, "reaction": Reaction, "parentId"?: string, "threadId"?: string } }` | thread room when applicable, otherwise namespace-wide | Used by chat/thread reaction UIs. |
| `reaction:updated` | implemented | `{ "data": { "id": string, "contentPath": string, "reaction": Reaction, "parentId"?: string, "threadId"?: string } }` | thread room when applicable, otherwise namespace-wide | Used by chat/thread reaction UIs. |
| `reaction:deleted` | implemented | `{ "data": { "id": string, "contentPath": string, "reaction": Reaction, "parentId"?: string, "threadId"?: string } }` | thread room when applicable, otherwise namespace-wide | Used by chat/thread reaction UIs. |
| `explore` | implemented | `{ "data": ExploreSection }` | namespace-wide | Sent repeatedly during an explore request. |
| `user:updated` | implemented | `{ "data": SafeUser }` | namespace-wide | Emitted from REST user profile updates. |

## Current client usage

The mobile client currently sends these socket events directly:

- `join:room`
- `leave:room`
- `message:created`
- `reaction:created`
- `reaction:updated`
- `reaction:deleted`

The mobile client currently listens for these broadcasts:

- `event:created`
- `event:updated`
- `event:deleted`
- `message:created`
- `message:updated`
- `message:deleted`
- `reaction:created`
- `reaction:updated`
- `reaction:deleted`
- `thread:locked`
- `thread:unlocked`

No current client subscription was found for:

- `thread:created`
- `thread:updated`
- `thread:deleted`
- `explore`
- `user:updated`

## Important implementation notes

- `message:updated` and `message:deleted` now work through both socket handlers and REST controllers, and both paths emit the same room-scoped broadcast event names.
- `event:updated` is emitted not only for explicit event edits, but also after join/leave and verify-attendance mutations when the underlying event state changes.
- Some broadcasts are namespace-wide and some are room-scoped. Chat-style listeners should join the relevant `thread:{threadId}` room before relying on thread-specific updates.
- Event payload shapes are not yet enforced from a shared schema package. This file is a source-of-truth snapshot, not a generated spec.

## Recommended next step

If you want this to evolve beyond a manual reference, the next step is to formalize it as:

- an `AsyncAPI` document, or
- a typed internal socket contract module that generates docs from shared schemas

That would let REST and sockets follow the same documentation discipline.
