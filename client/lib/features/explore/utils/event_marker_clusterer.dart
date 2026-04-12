import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/event_marker.dart';

class EventMarkerMapCluster {
  EventMarkerMapCluster({required this.center, required this.markers});

  final LatLng center;
  final List<EventMarker> markers;

  bool get isCluster => markers.length > 1;

  EventMarker get primaryMarker => markers.first;

  int get count => markers.length;
}

class EventMarkerClusterer {
  const EventMarkerClusterer();

  List<EventMarkerMapCluster> clusterMarkers(
    List<EventMarker> markers, {
    required double zoom,
    double clusterRadius = 88,
  }) {
    if (markers.isEmpty) return const [];

    final worldSize = 256 * pow(2, zoom).toDouble();
    final projected = <_ProjectedMarker>[];
    for (final marker in markers) {
      projected.add(
        _ProjectedMarker(
          marker: marker,
          point: _project(marker.latitude, marker.longitude, worldSize),
        ),
      );
    }

    final buckets = <String, List<int>>{};
    for (var index = 0; index < projected.length; index++) {
      final point = projected[index].point;
      final cellX = (point.x / clusterRadius).floor();
      final cellY = (point.y / clusterRadius).floor();
      final key = '$cellX:$cellY';
      buckets.putIfAbsent(key, () => <int>[]).add(index);
    }

    final visited = <int>{};
    final clusters = <EventMarkerMapCluster>[];

    for (var i = 0; i < projected.length; i++) {
      if (visited.contains(i)) continue;

      final queue = <int>[i];
      final clusterMarkers = <EventMarker>[];
      var sumLat = 0.0;
      var sumLng = 0.0;

      while (queue.isNotEmpty) {
        final currentIndex = queue.removeLast();
        if (!visited.add(currentIndex)) continue;

        final current = projected[currentIndex];
        clusterMarkers.add(current.marker);
        sumLat += current.marker.latitude;
        sumLng += current.marker.longitude;

        final cellX = (current.point.x / clusterRadius).floor();
        final cellY = (current.point.y / clusterRadius).floor();

        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            final neighborKey = '${cellX + dx}:${cellY + dy}';
            final candidates = buckets[neighborKey];
            if (candidates == null) continue;

            for (final candidateIndex in candidates) {
              if (visited.contains(candidateIndex) ||
                  currentIndex == candidateIndex) {
                continue;
              }

              if ((current.point - projected[candidateIndex].point).magnitude <=
                  clusterRadius) {
                queue.add(candidateIndex);
              }
            }
          }
        }
      }

      clusters.add(
        EventMarkerMapCluster(
          center: LatLng(
            sumLat / clusterMarkers.length,
            sumLng / clusterMarkers.length,
          ),
          markers: clusterMarkers,
        ),
      );
    }

    clusters.sort((a, b) => b.count.compareTo(a.count));
    return clusters;
  }

  Point<double> _project(double lat, double lng, double worldSize) {
    final x = (lng + 180) / 360 * worldSize;
    final sinLat = sin(lat * pi / 180).clamp(-0.9999, 0.9999);
    final y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) * worldSize;
    return Point<double>(x, y);
  }
}

class _ProjectedMarker {
  const _ProjectedMarker({required this.marker, required this.point});

  final EventMarker marker;
  final Point<double> point;
}
