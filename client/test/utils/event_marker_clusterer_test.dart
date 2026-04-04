import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/screens/explore/models/event_marker.dart';
import 'package:foody_mobile/screens/explore/utils/event_marker_clusterer.dart';

void main() {
  const clusterer = EventMarkerClusterer();

  EventMarker marker(String id, double lat, double lng) {
    return EventMarker(id: id, name: id, latitude: lat, longitude: lng);
  }

  test('clusters nearby markers into a single cluster', () {
    final clusters = clusterer.clusterMarkers(<EventMarker>[
      marker('a', 19.0760, 72.8777),
      marker('b', 19.0761, 72.8778),
      marker('c', 19.0762, 72.8779),
    ], zoom: 15);

    expect(clusters, hasLength(1));
    expect(clusters.first.count, 3);
    expect(clusters.first.isCluster, isTrue);
  });

  test('keeps distant markers separated', () {
    final clusters = clusterer.clusterMarkers(<EventMarker>[
      marker('a', 19.0760, 72.8777),
      marker('b', 19.1760, 72.9777),
      marker('c', 19.2760, 73.0777),
    ], zoom: 15);

    expect(clusters, hasLength(3));
    expect(clusters.every((cluster) => cluster.count == 1), isTrue);
  });

  test('preserves transitive clustering across neighboring cells', () {
    final clusters = clusterer.clusterMarkers(
      <EventMarker>[
        marker('a', 19.07600, 72.87770),
        marker('b', 19.07625, 72.87795),
        marker('c', 19.07650, 72.87820),
      ],
      zoom: 18,
      clusterRadius: 88,
    );

    expect(clusters, hasLength(1));
    expect(clusters.first.markers.map((marker) => marker.id).toSet(), {
      'a',
      'b',
      'c',
    });
  });
}
