export const CACHE_NAMESPACE_CONFIG = {
  Tags: {
    namespace: 'tags',
    ttl: 3600 * 24,
  },
  Events: {
    namespace: 'events',
    ttl: 3600 * 24,
  },
  Users: {
    namespace: 'users',
    ttl: 3600,
  },
  Threads: {
    namespace: 'threads',
    ttl: 3600 * 24,
  },
  Messages: {
    namespace: 'messages',
    ttl: 3600 * 24 * 2,
  },
  Reactions: {
    namespace: 'reactions',
    ttl: 1800,
  },
  Sessions: {
    namespace: 'session',
    ttl: 3600 * 24 * 30,
  },
  Media: {
    namespace: 'media',
    ttl: 3600 * 24,
  },
  MediaPublicUrl: {
    namespace: 'media-public-url',
    ttl: 3600 * 24,
  },
  Explore: {
    namespace: 'ex',
    ttl: 3600,
  },
  Activity: {
    namespace: 'ac',
    ttl: 900,
  },
  Achievements: {
    namespace: 'ah',
    ttl: 900,
  },
  Engagement: {
    namespace: 'eg',
    ttl: 3600 * 24 * 30,
  },
  RateLimit: {
    namespace: 'rl',
    ttl: 3600,
  },
  EntityStats: {
    namespace: 'st',
    ttl: 3600 * 24 * 30,
  },
};

export const PASSWORD_RESET_CONFIG = {
  otpNamespace: 'pwd_otp',
  otpTtl: 60 * 10, // 10 minutes
  tokenNamespace: 'pwd_token',
  tokenTtl: 60 * 15, // 15 minutes
  maxAttempts: 5,
};

export enum DB_CONNECTION_NAMES {
  Read = 'read',
  Write = 'write',
  Default = 'default',
}

export enum REDIS_CONNECTION_NAMES {
  Default = 'default',
  Sessions = 'sessions',
  Analytics = 'analytics',
  RateLimit = 'rate_limit',
  Cache = 'cache',
  Activity = 'activity',
}

export const PLATFORM_SOCKET_EVENTS = {
  CONNECT: 'connect',
  DISCONNECT: 'disconnect',
  JOIN_ROOM: 'join:room',
  LEAVE_ROOM: 'leave:room',

  // EVENTs
  EVENT_CREATE: 'event:create',
  EVENT_UPDATE: 'event:update',
  EVENT_DELETE: 'event:delete',

  // THREADs
  THREAD_CREATE: 'thread:create',
  THREAD_UPDATE: 'thread:update',
  THREAD_DELETE: 'thread:delete',
  THREAD_LOCK: 'thread:lock',
  THREAD_UNLOCK: 'thread:unlock',

  // MESSAGEs
  MESSAGE_CREATE: 'message:create',
  MESSAGE_UPDATE: 'message:update',
  MESSAGE_DELETE: 'message:delete',

  // REACTIONs
  REACTION_CREATE: 'reaction:create',
  REACTION_UPDATE: 'reaction:update',
  REACTION_DELETE: 'reaction:delete',

  // USERs
  USER_UPDATE: 'user:update',
  EXPLORE: 'explore',

  // ACTIVITYs
  ACTIVITY_NEW: 'activity:new',
};
