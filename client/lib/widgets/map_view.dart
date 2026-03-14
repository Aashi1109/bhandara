import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/maps/map_manager.dart';

/// Shared map widget for consistent map usage across screens.
///
/// Usage:
/// ```dart
/// AppMapView(
///   initialCameraPosition: const CameraPosition(
///     target: LatLng(21.1702, 79.6527),
///     zoom: 14,
///   ),
///   markers: {
///     const Marker(
///       markerId: MarkerId('home'),
///       position: LatLng(21.1702, 79.6527),
///     ),
///   },
/// )
/// ```
class AppMapView extends StatefulWidget {
  const AppMapView({
    super.key,
    required this.manager,
    required this.initialCameraPosition,
    this.markers = const <Marker>{},
    this.mapType = MapType.normal,
    this.zoomControlsEnabled = false,
    this.myLocationButtonEnabled = false,
    this.myLocationEnabled = false,
    this.padding = EdgeInsets.zero,
    this.mapStyle,
    this.onMapReady,
    this.onTap,
  });

  /// Initial camera target and zoom when the map first renders.
  final CameraPosition initialCameraPosition;

  /// Markers rendered on the map.
  final Set<Marker> markers;

  /// Google map visual type (normal, satellite, terrain, hybrid).
  final MapType mapType;

  /// Whether native zoom control buttons are shown.
  final bool zoomControlsEnabled;

  /// Whether the native "my location" button is shown.
  final bool myLocationButtonEnabled;

  /// Whether the blue user-location dot is enabled.
  final bool myLocationEnabled;

  /// Instantiated manager that routes calls to the selected provider service.
  final MapManager manager;

  /// Inner content padding for map camera controls and gestures.
  final EdgeInsets padding;

  /// Optional native map style JSON. Uses service default when null.
  final String? mapStyle;

  /// Callback fired once map controller is created.
  final ValueChanged<GoogleMapController>? onMapReady;

  /// Callback fired when user taps the map.
  final ValueChanged<LatLng>? onTap;

  @override
  State<AppMapView> createState() => _AppMapViewState();
}

class _AppMapViewState extends State<AppMapView> {
  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: widget.initialCameraPosition,
      markers: widget.markers,
      mapType: widget.mapType,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      myLocationEnabled: widget.myLocationEnabled,
      padding: widget.padding,
      style: widget.mapStyle ?? widget.manager.nativeMapStyle,
      onTap: widget.onTap,
      onMapCreated: (controller) {
        widget.onMapReady?.call(controller);
      },
    );
  }
}
