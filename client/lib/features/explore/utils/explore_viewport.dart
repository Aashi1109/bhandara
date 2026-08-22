import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ExploreMapQueryMode { followLocation, viewport }

class ExploreViewportQuery {
  const ExploreViewportQuery({
    required this.center,
    required this.radiusKm,
    required this.zoom,
  });

  final LatLng center;
  final double radiusKm;
  final double zoom;
}

/// Axis-aligned lat/lng box. Used to drop markers outside the visible area
/// before they reach the clusterer.
///
/// ponytail: does not wrap the antimeridian — a viewport straddling ±180°
/// renders nothing on the far side. Split into two boxes if that ever ships.
class GeoBounds {
  const GeoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool contains(double latitude, double longitude) {
    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;
  }
}

const double _kmPerDegreeLat = 110.574;
const double _kmPerDegreeLngAtEquator = 111.320;

/// Bounding box covering a circle of [radiusKm] around [center].
GeoBounds boundsAround(LatLng center, double radiusKm) {
  final latDelta = radiusKm / _kmPerDegreeLat;
  final cosLat = cos(center.latitude * pi / 180).abs();
  final lngDelta = cosLat < 1e-6
      ? 180.0
      : radiusKm / (_kmPerDegreeLngAtEquator * cosLat);

  return GeoBounds(
    minLat: (center.latitude - latDelta).clamp(-90.0, 90.0),
    maxLat: (center.latitude + latDelta).clamp(-90.0, 90.0),
    minLng: (center.longitude - lngDelta).clamp(-180.0, 180.0),
    maxLng: (center.longitude + lngDelta).clamp(-180.0, 180.0),
  );
}

double distanceInMetersBetween(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(endLat - startLat);
  final dLng = _toRadians(endLng - startLng);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(startLat)) *
          cos(_toRadians(endLat)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double distanceBetweenLatLng(LatLng start, LatLng end) {
  return distanceInMetersBetween(
    start.latitude,
    start.longitude,
    end.latitude,
    end.longitude,
  );
}

double viewportRadiusKmFromCorners({
  required LatLng center,
  required Iterable<LatLng> corners,
  double bufferMultiplier = 1.1,
}) {
  final farthestDistance = corners.fold<double>(
    0,
    (maxDistance, corner) =>
        max(maxDistance, distanceBetweenLatLng(center, corner)),
  );

  return (farthestDistance * bufferMultiplier) / 1000;
}

/// Whether [next] differs from [previous] enough to justify a refetch.
///
/// Thresholds scale with the visible radius: a 250 m pan is a real move at
/// street level and pure noise at country level. Fixed thresholds meant every
/// pixel of drag refetched when zoomed out.
bool hasMeaningfulViewportChange(
  ExploreViewportQuery? previous,
  ExploreViewportQuery next, {
  double zoomThreshold = 0.25,
}) {
  if (previous == null) {
    return true;
  }

  final centerThresholdMeters = (next.radiusKm * 1000 * 0.12).clamp(
    150.0,
    50000.0,
  );
  final radiusThresholdKm = (next.radiusKm * 0.15).clamp(0.25, 50.0);

  final centerDistance = distanceBetweenLatLng(previous.center, next.center);
  final radiusDelta = (previous.radiusKm - next.radiusKm).abs();
  final zoomDelta = (previous.zoom - next.zoom).abs();

  return centerDistance >= centerThresholdMeters ||
      radiusDelta >= radiusThresholdKm ||
      zoomDelta >= zoomThreshold;
}

String buildExploreCacheLocationKey({
  required ExploreMapQueryMode mode,
  LatLng? followLocation,
  double? followRadiusKm,
  ExploreViewportQuery? viewport,
}) {
  switch (mode) {
    case ExploreMapQueryMode.followLocation:
      final locationKey = followLocation == null
          ? 'no-location'
          : '${followLocation.latitude.toStringAsFixed(3)},${followLocation.longitude.toStringAsFixed(3)}';
      final radiusKey = followRadiusKm == null
          ? 'no-radius'
          : followRadiusKm.toStringAsFixed(1);
      return 'follow|$locationKey|$radiusKey';
    case ExploreMapQueryMode.viewport:
      if (viewport == null) {
        return 'viewport|pending';
      }
      return [
        'viewport',
        viewport.center.latitude.toStringAsFixed(3),
        viewport.center.longitude.toStringAsFixed(3),
        viewport.radiusKm.toStringAsFixed(1),
        viewport.zoom.toStringAsFixed(1),
      ].join('|');
  }
}

double _toRadians(double value) => value * pi / 180;
