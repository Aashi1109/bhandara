import { describe, expect, it } from 'vitest';

import { MAX_FLAT_MARKER_RADIUS_KM, normalizeFlatMarkerViewport } from '@/features/events/helpers';

const KM_PER_DEGREE_LAT = 110.574;
const KM_PER_DEGREE_LNG = 111.32;

const distanceKm = (aLat: number, aLng: number, bLat: number, bLng: number) => {
  const dLat = (bLat - aLat) * KM_PER_DEGREE_LAT;
  const dLng = (bLng - aLng) * KM_PER_DEGREE_LNG * Math.cos((aLat * Math.PI) / 180);
  return Math.hypot(dLat, dLng);
};

describe('normalizeFlatMarkerViewport', () => {
  it('leaves incomplete viewports untouched', () => {
    expect(normalizeFlatMarkerViewport({ latitude: 19, longitude: 72 })).toEqual({ latitude: 19, longitude: 72 });
    expect(normalizeFlatMarkerViewport({ latitude: 19, longitude: 72, radiusKm: 0 }).radiusKm).toBe(0);
  });

  it('collapses nearby viewports onto the same query so the cache can hit', () => {
    const base = normalizeFlatMarkerViewport({ latitude: 19.076, longitude: 72.8777, radiusKm: 12 });
    const nudged = normalizeFlatMarkerViewport({ latitude: 19.0765, longitude: 72.8781, radiusKm: 12.1 });

    expect(nudged).toEqual(base);
  });

  it('always returns a circle that contains the requested one', () => {
    // A snapped circle that did not cover the request would let the client
    // claim coverage over an area it never fetched, silently hiding markers.
    for (const radiusKm of [0.5, 3, 12, 47, 180, 900]) {
      for (const latitude of [-62.5, -8.25, 0, 19.076, 51.5074]) {
        for (const offset of [0, 0.017, 0.041, 0.099]) {
          const longitude = 72.8777 + offset;
          const snapped = normalizeFlatMarkerViewport({ latitude, longitude, radiusKm });
          const drift = distanceKm(latitude, longitude, snapped.latitude!, snapped.longitude!);
          const requested = Math.min(radiusKm, MAX_FLAT_MARKER_RADIUS_KM);

          if (snapped.radiusKm! >= MAX_FLAT_MARKER_RADIUS_KM) {
            // At the cap the circle is deliberately smaller than the request:
            // the response is truncated anyway, and the echoed radius has to
            // stay honest so the client never claims uncovered ground.
            expect(snapped.radiusKm).toBe(MAX_FLAT_MARKER_RADIUS_KM);
            continue;
          }

          expect(drift + requested).toBeLessThanOrEqual(snapped.radiusKm!);
        }
      }
    }
  });

  it('clamps runaway radii', () => {
    const snapped = normalizeFlatMarkerViewport({ latitude: 19.076, longitude: 72.8777, radiusKm: 20000 });
    expect(snapped.radiusKm).toBe(MAX_FLAT_MARKER_RADIUS_KM);
  });
});
