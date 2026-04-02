import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventCluster {
  const EventCluster({
    required this.latitude,
    required this.longitude,
    required this.count,
  });

  factory EventCluster.fromJson(Map<String, dynamic> json) {
    return EventCluster(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      count: (json['count'] as num).toInt(),
    );
  }

  final double latitude;
  final double longitude;
  final int count;

  LatLng get position => LatLng(latitude, longitude);
}
