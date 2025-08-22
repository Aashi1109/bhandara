export const CACHE_NAMESPACE_CONFIG = {
  Tags: {
    namespace: "tags",
    ttl: 3600 * 24,
  },
  Events: {
    namespace: "events",
    ttl: 3600 * 24,
  },
  Users: {
    namespace: "users",
    ttl: 3600,
  },
  Threads: {
    namespace: "threads",
    ttl: 3600 * 24,
  },
  Messages: {
    namespace: "messages",
    ttl: 3600 * 24 * 2,
  },
  Reactions: {
    namespace: "reactions",
    ttl: 1800,
  },
  Sessions: {
    namespace: "session",
    ttl: 3600 * 24 * 30,
  },
  Media: {
    namespace: "media",
    ttl: 3600 * 24,
  },
  MediaPublicUrl: {
    namespace: "media-public-url",
    ttl: 3600 * 24,
  },
  Explore: {
    namespace: "explore-pages",
    ttl: 3600,
  },
};

export enum DB_CONNECTION_NAMES {
  Read = "read",
  Write = "write",
  Default = "default",
}

export const PLATFORM_SOCKET_EVENTS = {
  CONNECT: "connect",
  DISCONNECT: "disconnect",
  JOIN_ROOM: "join:room",
  LEAVE_ROOM: "leave:room",

  // EVENTs
  EVENT_CREATED: "event:created",
  EVENT_UPDATED: "event:updated",
  EVENT_DELETED: "event:deleted",

  // THREADs
  THREAD_CREATED: "thread:created",
  THREAD_UPDATED: "thread:updated",
  THREAD_DELETED: "thread:deleted",
  THREAD_LOCKED: "thread:locked",
  THREAD_UNLOCKED: "thread:unlocked",

  // MESSAGEs
  MESSAGE_CREATED: "message:created",
  MESSAGE_UPDATED: "message:updated",
  MESSAGE_DELETED: "message:deleted",

  // REACTIONs
  REACTION_CREATED: "reaction:created",
  REACTION_UPDATED: "reaction:updated",
  REACTION_DELETED: "reaction:deleted",

  // USERs
  USER_UPDATED: "user:updated",
  EXPLORE: "explore",
};
