import 'dart:math';

import 'package:dart_geohash/dart_geohash.dart';
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

bool hasMeaningfulViewportChange(
  ExploreViewportQuery? previous,
  ExploreViewportQuery next, {
  double centerThresholdMeters = 250,
  double radiusThresholdKm = 0.5,
  double zoomThreshold = 0.2,
}) {
  if (previous == null) {
    return true;
  }

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

const double clusterZoomThreshold = 12.0;

int geohashPrecisionFromZoom(double zoom) {
  if (zoom < 15) return 5;
  if (zoom < 18) return 6;
  return 7;
}

Set<String> computeVisibleGeohashTiles({
  required LatLng sw,
  required LatLng ne,
  required double zoom,
}) {
  final precision = geohashPrecisionFromZoom(zoom);
  final geoHasher = GeoHasher();
  final totalBits = precision * 5;
  final lngBits = (totalBits / 2).ceil();
  final latBits = totalBits ~/ 2;

  // Geohash interleaves longitude first, then latitude.
  // Odd precisions therefore allocate the extra bit to longitude.
  final latStep = 180.0 / pow(2, latBits);
  final lngStep = 360.0 / pow(2, lngBits);

  final tiles = <String>{};
  var lat = sw.latitude;
  while (lat <= ne.latitude + latStep) {
    var lng = sw.longitude;
    while (lng <= ne.longitude + lngStep) {
      final clampedLat = lat.clamp(-90.0, 90.0);
      final clampedLng = lng.clamp(-180.0, 180.0);
      tiles.add(geoHasher.encode(clampedLng, clampedLat, precision: precision));
      lng += lngStep;
    }
    lat += latStep;
  }

  return tiles;
}
