import 'user.dart';

enum LocationSelectionMode { settings, picker }

class LocationScreenArgs {
  const LocationScreenArgs({
    this.mode = LocationSelectionMode.settings,
    this.initialLocation,
    this.initialCameraLatitude,
    this.initialCameraLongitude,
    this.initialZoom,
  });

  final LocationSelectionMode mode;
  final UserAddress? initialLocation;
  final double? initialCameraLatitude;
  final double? initialCameraLongitude;
  final double? initialZoom;
}

class LocationPickerResult {
  const LocationPickerResult({
    required this.location,
    required this.cameraLatitude,
    required this.cameraLongitude,
    required this.zoom,
  });

  final UserAddress location;
  final double cameraLatitude;
  final double cameraLongitude;
  final double zoom;
}
