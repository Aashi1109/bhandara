import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../features/events/models/event.dart';

class EventMapCluster {
  EventMapCluster({required this.center, required this.events});

  final LatLng center;
  final List<Event> events;

  bool get isCluster => events.length > 1;

  Event get primaryEvent => events.first;

  int get count => events.length;
}

class MapClusterer {
  const MapClusterer();

  List<EventMapCluster> clusterEvents(
    List<Event> events, {
    required double zoom,
    double clusterRadius = 88,
  }) {
    if (events.isEmpty) {
      return const [];
    }

    final worldSize = 256 * math.pow(2, zoom).toDouble();
    final projectedEvents = <_ProjectedEvent>[];

    for (final event in events) {
      final lat = event.location.latitude;
      final lng = event.location.longitude;
      if (lat == null || lng == null) {
        continue;
      }

      projectedEvents.add(
        _ProjectedEvent(
          event: event,
          point: _project(lat, lng, worldSize),
        ),
      );
    }

    final visited = <int>{};
    final clusters = <EventMapCluster>[];

    for (var i = 0; i < projectedEvents.length; i++) {
      if (visited.contains(i)) {
        continue;
      }

      final queue = <int>[i];
      final clusterEvents = <Event>[];
      var sumLat = 0.0;
      var sumLng = 0.0;

      while (queue.isNotEmpty) {
        final currentIndex = queue.removeLast();
        if (!visited.add(currentIndex)) {
          continue;
        }

        final current = projectedEvents[currentIndex];
        final event = current.event;
        clusterEvents.add(event);
        sumLat += event.location.latitude!;
        sumLng += event.location.longitude!;

        for (var j = 0; j < projectedEvents.length; j++) {
          if (visited.contains(j) || currentIndex == j) {
            continue;
          }

          final candidate = projectedEvents[j];
          if ((current.point - candidate.point).magnitude <= clusterRadius) {
            queue.add(j);
          }
        }
      }

      clusters.add(
        EventMapCluster(
          center: LatLng(
            sumLat / clusterEvents.length,
            sumLng / clusterEvents.length,
          ),
          events: clusterEvents,
        ),
      );
    }

    clusters.sort((a, b) => b.count.compareTo(a.count));
    return clusters;
  }

  math.Point<double> _project(
    double latitude,
    double longitude,
    double worldSize,
  ) {
    final x = (longitude + 180) / 360 * worldSize;
    final sinLatitude = math
        .sin(latitude * math.pi / 180)
        .clamp(-0.9999, 0.9999);
    final y =
        (0.5 -
            math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) *
            worldSize;

    return math.Point<double>(x, y);
  }
}

class _ProjectedEvent {
  const _ProjectedEvent({
    required this.event,
    required this.point,
  });

  final Event event;
  final math.Point<double> point;
}
