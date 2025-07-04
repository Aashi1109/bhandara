import { RedisCache } from "@features/cache";
import { CACHE_NAMESPACE_CONFIG } from "@constants";
import { IBaseUser, IEvent } from "@definitions/types";

const eventCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Events.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Events.ttl,
});

/** Fetch an event from cache by ID. */
export const getEventCache = (eventId: string) =>
  eventCache.getItem<IEvent>(`${eventId}`);

/** Store an event in cache. */
export const setEventCache = (eventId: string, event: IEvent) =>
  eventCache.setItem(`${eventId}`, event);

/** Remove all cached entries for an event. */
export const deleteEventCache = (eventId: string) =>
  eventCache.deleteItem(`${eventId}*`);

/** Retrieve cached users for an event. */
export const getEventUsersCache = (key: string) =>
  eventCache.getItem<Record<string, IBaseUser>>(key);

/** Cache a map of users for an event. */
export const setEventUsersCache = (
  key: string,
  users: Record<string, IBaseUser>
) => eventCache.setItem(key, users);
