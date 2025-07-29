export const BASE_AVATAR_URL = "https://cdn.jsdelivr.net/gh/alohe/avatars/png/memo_{num}.png";

export const AVATAR_BUCKET = "avatars";
export const EVENT_MEDIA_BUCKET = "event-files";

export const EVENT_VERIFY_RADIUS_M = 50;

export const PLATFORM_SOCKET_EVENTS = {
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
  EXPLORE: "explore"
};

export const COMMON_EMOJIS = ["👍", "❤️", "😂", "🎉", "😮", "😢"];
