import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/explore/models/event_marker.dart';
import 'package:foody_mobile/features/explore/utils/event_marker_clusterer.dart';
import 'package:foody_mobile/features/explore/utils/explore_viewport.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('boundsAround covers every point inside the circle', () {
    // The map clips the marker store with this box before clustering, so a box
    // that under-covers the circle silently drops on-screen pins.
    const center = LatLng(19.076, 72.8777);
    const radiusKm = 25.0;
    final bounds = boundsAround(center, radiusKm);

    for (var bearing = 0; bearing < 360; bearing += 15) {
      final radians = bearing * pi / 180;
      // Slightly inside the circle so floating point never lands us outside.
      const distanceKm = radiusKm * 0.999;
      final latitude = center.latitude + (distanceKm * cos(radians)) / 110.574;
      final longitude =
          center.longitude +
          (distanceKm * sin(radians)) /
              (111.320 * cos(center.latitude * pi / 180));

      expect(
        bounds.contains(latitude, longitude),
        isTrue,
        reason: 'bearing $bearing dropped',
      );
    }

    expect(bounds.contains(center.latitude + 1.0, center.longitude), isFalse);
  });

  test('clusterer groups a dense blob and keeps distant pins separate', () {
    // 400 markers on one city block plus one far away. Before the `enqueued`
    // guard the flood fill re-queued each index once per neighbouring cell.
    final markers = <EventMarker>[
      for (var i = 0; i < 400; i++)
        EventMarker(
          id: 'dense-$i',
          name: 'dense $i',
          latitude: 19.076 + (i % 20) * 0.00002,
          longitude: 72.8777 + (i ~/ 20) * 0.00002,
        ),
      const EventMarker(
        id: 'far',
        name: 'far',
        latitude: 28.6139,
        longitude: 77.2090,
      ),
    ];

    final clusters = const EventMarkerClusterer().clusterMarkers(
      markers,
      zoom: 12,
    );

    expect(clusters.length, 2);
    expect(clusters.first.count, 400);
    expect(clusters.last.primaryMarker.id, 'far');
    // Every marker lands in exactly one cluster.
    expect(
      clusters.fold<int>(0, (total, cluster) => total + cluster.count),
      markers.length,
    );
  });
}
