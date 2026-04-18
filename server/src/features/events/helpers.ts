import { RedisCache } from '@/src/features/cache';
import { CACHE_NAMESPACE_CONFIG } from '@/src/common/constants';
import type { IBaseUser, IEvent } from '@/src/common/definitions/types';
import { createHash } from 'crypto';
import type { IEventListFilters } from './service';

const eventCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Events.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Events.ttl,
});

/** Fetch an event from cache by ID. */
export const getEventCache = (eventId: string) => eventCache.getItem<IEvent>(`${eventId}`);

/** Store an event in cache. */
export const setEventCache = (eventId: string, event: IEvent) => eventCache.setItem(`${eventId}`, event);

/** Remove all cached entries for an event. */
export const deleteEventCache = (eventId: string) => eventCache.invalidateCache(`${eventId}*`);

/** Fetch a lightweight event preview from cache. */
export const getEventPreviewCache = (eventId: string) => eventCache.getItem<IEvent>(`${eventId}:preview`);

/** Store a lightweight event preview in cache. */
export const setEventPreviewCache = (eventId: string, event: IEvent) => eventCache.setItem(`${eventId}:preview`, event);

/** Retrieve cached users for an event. */
export const getEventUsersCache = (key: string) => eventCache.getItem<Record<string, IBaseUser>>(key);

/** Cache a map of users for an event. */
export const setEventUsersCache = (key: string, users: Record<string, IBaseUser>) => eventCache.setItem(key, users);

const markerCache = new RedisCache({
  namespace: 'markers',
  defaultTTLSeconds: 60,
});

function buildMarkerCacheKey(
  mode: 'flat' | 'clusters' | 'tiles',
  filters: IEventListFilters,
  options: { zoom?: number; tiles?: string[] },
): string {
  const payload = JSON.stringify({
    mode,
    zoom: options.zoom,
    tiles: options.tiles ? [...options.tiles].sort() : undefined,
    lat: filters.latitude?.toFixed(3),
    lng: filters.longitude?.toFixed(3),
    radius: filters.radiusKm,
    statuses: filters.statuses ? [...filters.statuses].sort() : undefined,
    types: filters.types ? [...filters.types].sort() : undefined,
    tagIds: filters.tagIds ? [...filters.tagIds].sort() : undefined,
    startDate: filters.startDate?.toISOString(),
    endDate: filters.endDate?.toISOString(),
    createdBy: filters.createdBy,
  });
  const hash = createHash('sha256').update(payload).digest('hex').slice(0, 16);
  return `${mode}:${hash}`;
}

export const getMarkerCache = <T>(
  mode: 'flat' | 'clusters' | 'tiles',
  filters: IEventListFilters,
  options: { zoom?: number; tiles?: string[] },
) => markerCache.getItem<T>(buildMarkerCacheKey(mode, filters, options));

export const setMarkerCache = <T>(
  mode: 'flat' | 'clusters' | 'tiles',
  filters: IEventListFilters,
  options: { zoom?: number; tiles?: string[] },
  value: T,
) => markerCache.setItem(buildMarkerCacheKey(mode, filters, options), value);
