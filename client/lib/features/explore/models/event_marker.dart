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
