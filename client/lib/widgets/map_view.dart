import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/google_maps_web_loader.dart';
import '../theme/theme.dart';

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
    this.circles = const <Circle>{},
    this.mapType = MapType.normal,
    this.zoomControlsEnabled = false,
    this.myLocationButtonEnabled = false,
    this.myLocationEnabled = false,
    this.padding = EdgeInsets.zero,
    this.mapStyle,
    this.onMapReady,
    this.onTap,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  /// Initial camera target and zoom when the map first renders.
  final CameraPosition initialCameraPosition;

  /// Markers rendered on the map.
  final Set<Marker> markers;

  /// Circles rendered on the map.
  final Set<Circle> circles;

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

  /// Callback fired when the camera starts moving.
  final VoidCallback? onCameraMoveStarted;

  /// Callback fired when camera position changes.
  final ValueChanged<CameraPosition>? onCameraMove;

  /// Callback fired once camera stops moving.
  final VoidCallback? onCameraIdle;

  /// Gesture recognizers passed through to the native map.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<AppMapView> createState() => _AppMapViewState();
}

class _AppMapViewState extends State<AppMapView> {
  late final Future<void> _webMapsLoader = kIsWeb
      ? ensureGoogleMapsWebSdkLoaded(AppConfig.googleMapsApiKey)
      : Future<void>.value();

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<void>(
        future: _webMapsLoader,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ColoredBox(
              color: AppColors.muted,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Map unavailable on web.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(
              color: AppColors.muted,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            );
          }

          return _buildGoogleMap();
        },
      );
    }

    return _buildGoogleMap();
  }

  Widget _buildGoogleMap() {
    return ColoredBox(
      color: AppColors.muted,
      child: GoogleMap(
        initialCameraPosition: widget.initialCameraPosition,
        markers: widget.markers,
        circles: widget.circles,
        mapType: widget.mapType,
        zoomControlsEnabled: widget.zoomControlsEnabled,
        myLocationButtonEnabled: widget.myLocationButtonEnabled,
        myLocationEnabled: widget.myLocationEnabled,
        padding: widget.padding,
        style: widget.mapStyle ?? widget.manager.nativeMapStyle,
        gestureRecognizers: widget.gestureRecognizers,
        onTap: widget.onTap,
        onCameraMoveStarted: widget.onCameraMoveStarted,
        onCameraMove: widget.onCameraMove,
        onCameraIdle: widget.onCameraIdle,
        onMapCreated: (controller) {
          if (kIsWeb) {
            final style = widget.mapStyle ?? widget.manager.nativeMapStyle;
            if (style.isNotEmpty) {
              // ignore: deprecated_member_use
              controller.setMapStyle(style);
            }
          }
          widget.onMapReady?.call(controller);
        },
      ),
    );
  }
}
