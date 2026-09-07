import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventMarker {
  const EventMarker({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory EventMarker.fromJson(Map<String, dynamic> json) {
    return EventMarker(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  LatLng get position => LatLng(latitude, longitude);
}

/// Result of a flat-marker fetch.
///
/// [center] and [radiusKm] describe the circle the server actually queried: it
/// clamps and grid-snaps the request for cache reuse, so the caller must cache
/// this region rather than the one it asked for. [truncated] is true when the
/// row cap was hit and the caller should tell the user to zoom in.
class EventMarkerPage {
  const EventMarkerPage({
    required this.markers,
    required this.center,
    required this.radiusKm,
    required this.truncated,
  });

  final List<EventMarker> markers;
  final LatLng center;
  final double radiusKm;
  final bool truncated;
}
