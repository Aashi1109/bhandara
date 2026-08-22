import { RedisCache } from '@/features/cache';
import { CACHE_NAMESPACE_CONFIG } from '@/common/constants';
import type { IBaseUser, IEvent } from '@/common/definitions/types';
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
    // Full precision on purpose: flat-marker viewports are already grid-snapped
    // by the service before they reach here, so the key is stable across a pan.
    // Rounding here instead would silently merge distinct queries.
    lat: filters.latitude,
    lng: filters.longitude,
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

export const MAX_FLAT_MARKER_RADIUS_KM = 250;
const KM_PER_DEGREE_LAT = 110.574;
const KM_PER_DEGREE_LNG = 111.32;

/**
 * Snaps a flat-marker viewport to a coarse grid so panning inside a cell
 * produces an identical query — and therefore an actual Redis cache hit.
 * Keying on a raw 3-decimal centre never hit: pan centres are continuous, so
 * every request minted a fresh key.
 *
 * The returned circle always *contains* the requested one, so a client that
 * caches the echoed centre/radius never claims coverage it does not have.
 */
export const normalizeFlatMarkerViewport = (filters: IEventListFilters): IEventListFilters => {
  const { latitude, longitude, radiusKm } = filters;
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    !Number.isFinite(radiusKm) ||
    (radiusKm ?? 0) <= 0
  ) {
    return filters;
  }

  const clampedKm = Math.min(radiusKm!, MAX_FLAT_MARKER_RADIUS_KM);
  const bucketKm = Math.min(2 ** Math.ceil(Math.log2(Math.max(clampedKm, 1))), MAX_FLAT_MARKER_RADIUS_KM);
  const stepKm = bucketKm / 4;

  // A plain degree grid, deliberately not scaled by cos(latitude): scaling the
  // longitude step by the *requested* latitude gave neighbouring requests
  // different grids, so they never shared a cache entry. It also keeps the
  // containment bound latitude-independent, since cos(lat) <= 1 only ever
  // shrinks the east-west span of a cell.
  const stepLat = stepKm / KM_PER_DEGREE_LAT;
  const stepLng = stepKm / KM_PER_DEGREE_LNG;

  return {
    ...filters,
    latitude: Math.round(latitude! / stepLat) * stepLat,
    longitude: Math.round(longitude! / stepLng) * stepLng,
    // Worst-case centre shift is half a cell diagonal (~0.18 x bucket), so
    // 1.2x guarantees the snapped circle still covers the requested one — up
    // to the hard cap, which wins. Past the cap the response is truncated by
    // design, and the echoed radius must stay honest: the client treats it as
    // the region it may serve from memory, so overstating it would hide
    // markers just outside the circle that was actually queried.
    radiusKm: Math.min(bucketKm * 1.2, MAX_FLAT_MARKER_RADIUS_KM),
  };
};
