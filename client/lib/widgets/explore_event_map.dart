import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../services/maps/map_clusterer.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/map_marker_factory.dart';
import '../theme/theme.dart';
import 'map_view.dart';

class ExploreEventMap extends StatefulWidget {
  const ExploreEventMap({
    super.key,
    required this.manager,
    required this.events,
    required this.selectedEvent,
    required this.userLocation,
    required this.onEventSelected,
    this.onClusterFocusStart,
  });

  final MapManager manager;
  final List<Event> events;
  final Event? selectedEvent;
  final LatLng? userLocation;
  final ValueChanged<Event> onEventSelected;
  final VoidCallback? onClusterFocusStart;

  @override
  State<ExploreEventMap> createState() => _ExploreEventMapState();
}

class _ExploreEventMapState extends State<ExploreEventMap>
    with SingleTickerProviderStateMixin {
  static const double _initialZoom = 11;
  static const double _userPulseMinRadius = 30;
  static const double _userPulseMaxRadius = 120;

  final MapClusterer _clusterer = const MapClusterer();
  final Map<int, BitmapDescriptor> _clusterMarkerCache = {};
  final Set<int> _pendingClusterIcons = <int>{};
  final ValueNotifier<Set<Marker>> _markersNotifier =
      ValueNotifier<Set<Marker>>(const <Marker>{});
  final ValueNotifier<Set<Circle>> _circlesNotifier =
      ValueNotifier<Set<Circle>>(const <Circle>{});

  GoogleMapController? _mapController;
  BitmapDescriptor? _eventMarkerIcon;
  BitmapDescriptor? _selectedEventMarkerIcon;
  BitmapDescriptor? _userLocationMarkerIcon;
  late final AnimationController _pulseController;
  double _mapZoom = _initialZoom;
  double _pendingZoom = _initialZoom;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(_rebuildUserLocationPulse)
      ..repeat();
    _loadMarkerIcons();
    _rebuildMapMarkers();
    _rebuildUserLocationPulse();
  }

  @override
  void didUpdateWidget(covariant ExploreEventMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final eventsChanged = oldWidget.events != widget.events;
    final selectedChanged =
        oldWidget.selectedEvent?.id != widget.selectedEvent?.id;
    final locationChanged = oldWidget.userLocation != widget.userLocation;

    if (eventsChanged || selectedChanged || locationChanged) {
      _rebuildMapMarkers();
      if (locationChanged) {
        _rebuildUserLocationPulse();
      }
    }

    if (eventsChanged || locationChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitCameraToVisibleContent();
      });
    }
  }

  Future<void> _loadMarkerIcons() async {
    final results = await Future.wait([
      MapMarkerFactory.createFoodEventMarker(),
      MapMarkerFactory.createFoodEventMarker(highlighted: true),
      MapMarkerFactory.createUserLocationMarker(),
    ]);

    if (!mounted) return;
    _eventMarkerIcon = results[0];
    _selectedEventMarkerIcon = results[1];
    _userLocationMarkerIcon = results[2];
    _rebuildMapMarkers();
  }

  LatLng _getInitialMapCenter() {
    final userLocation = widget.userLocation;
    if (userLocation != null) {
      return userLocation;
    }

    for (final event in widget.events) {
      final lat = event.location.latitude;
      final lng = event.location.longitude;
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return const LatLng(21.1458, 79.0882);
  }

  void _rebuildMapMarkers() {
    _markersNotifier.value = _buildMarkers();
  }

  void _rebuildUserLocationPulse() {
    final userLocation = widget.userLocation;
    if (userLocation == null) {
      _circlesNotifier.value = const <Circle>{};
      return;
    }

    final progress = _pulseController.value;
    final radius =
        _userPulseMinRadius +
        ((_userPulseMaxRadius - _userPulseMinRadius) * progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);

    _circlesNotifier.value = <Circle>{
      Circle(
        circleId: const CircleId('user_location_pulse'),
        center: userLocation,
        radius: radius,
        fillColor: AppColors.primary.withValues(alpha: opacity * 0.12),
        strokeColor: AppColors.primary.withValues(alpha: opacity * 0.28),
        strokeWidth: 2,
        zIndex: 1,
      ),
      Circle(
        circleId: const CircleId('user_location_halo'),
        center: userLocation,
        radius: 18,
        fillColor: AppColors.primary.withValues(alpha: 0.16),
        strokeColor: AppColors.primary.withValues(alpha: 0.28),
        strokeWidth: 1,
        zIndex: 2,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final clusters = _clusterer.clusterEvents(widget.events, zoom: _mapZoom);

    for (final cluster in clusters) {
      if (cluster.isCluster) {
        final clusterIcon = _resolveClusterMarker(cluster.count);
        if (clusterIcon == null) {
          continue;
        }
        markers.add(
          Marker(
            markerId: MarkerId(
              'cluster_${cluster.center.latitude}_${cluster.center.longitude}_${cluster.count}',
            ),
            position: cluster.center,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
            icon: clusterIcon,
            onTap: () => _focusOnCluster(cluster),
          ),
        );
        continue;
      }

      final event = cluster.primaryEvent;
      final isSelected = widget.selectedEvent?.id == event.id;
      final eventIcon = isSelected
          ? _selectedEventMarkerIcon
          : _eventMarkerIcon;
      if (eventIcon == null) {
        continue;
      }
      markers.add(
        Marker(
          markerId: MarkerId(event.id),
          position: cluster.center,
          icon: eventIcon,
          infoWindow: InfoWindow(title: event.name),
          onTap: () => widget.onEventSelected(event),
        ),
      );
    }

    final userLocation = widget.userLocation;
    if (userLocation != null && _userLocationMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: userLocation,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 3,
          icon: _userLocationMarkerIcon!,
        ),
      );
    }

    return markers;
  }

  BitmapDescriptor? _resolveClusterMarker(int count) {
    final cached = _clusterMarkerCache[count];
    if (cached != null) return cached;
    if (_pendingClusterIcons.contains(count)) return null;

    _pendingClusterIcons.add(count);
    MapMarkerFactory.createClusterMarker(count: count).then((icon) {
      if (!mounted) return;
      _clusterMarkerCache[count] = icon;
      _pendingClusterIcons.remove(count);
      _rebuildMapMarkers();
    });

    return null;
  }

  List<LatLng> _contentPoints() {
    final points = <LatLng>[];
    if (widget.userLocation != null) {
      points.add(widget.userLocation!);
    }

    for (final event in widget.events) {
      final lat = event.location.latitude;
      final lng = event.location.longitude;
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  Future<void> _fitCameraToVisibleContent() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = _contentPoints();
    if (points.isEmpty) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_getInitialMapCenter(), _initialZoom),
      );
      return;
    }

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 12.5),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (controller == null) return;
    final zoom = await controller.getZoomLevel();
    await controller.animateCamera(
      CameraUpdate.zoomTo((zoom + 1).clamp(2, 20).toDouble()),
    );
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (controller == null) return;
    final zoom = await controller.getZoomLevel();
    await controller.animateCamera(
      CameraUpdate.zoomTo((zoom - 1).clamp(2, 20).toDouble()),
    );
  }

  Future<void> _focusOnVisibleContent() async {
    await _fitCameraToVisibleContent();
  }

  Future<void> _focusOnCluster(EventMapCluster cluster) async {
    widget.onClusterFocusStart?.call();
    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(cluster.center, (_mapZoom + 2).clamp(4, 20)),
    );
  }

  void _handleCameraIdle() {
    if (!mounted) return;
    final nextZoom = _pendingZoom;
    if ((nextZoom - _mapZoom).abs() < 0.05) return;
    setState(() {
      _mapZoom = nextZoom;
    });
    _rebuildMapMarkers();
  }

  Widget _mapControl(IconData icon, bool isPrimary, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: AppIconSizes.defaultSize,
          color: isPrimary ? AppColors.surface : AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<Set<Marker>>(
            valueListenable: _markersNotifier,
            builder: (context, markers, _) {
              return ValueListenableBuilder<Set<Circle>>(
                valueListenable: _circlesNotifier,
                builder: (context, circles, _) {
                  return AppMapView(
                    manager: widget.manager,
                    initialCameraPosition: CameraPosition(
                      target: _getInitialMapCenter(),
                      zoom: _initialZoom,
                    ),
                    markers: markers,
                    circles: circles,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    onMapReady: (controller) {
                      _mapController = controller;
                      unawaited(_fitCameraToVisibleContent());
                    },
                    onCameraMove: (position) => _pendingZoom = position.zoom,
                    onCameraIdle: _handleCameraIdle,
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          right: 20,
          top: MediaQuery.of(context).size.height * 0.5 - 60,
          child: Column(
            children: [
              _mapControl(LucideIcons.plus, false, onTap: _zoomIn),
              const SizedBox(height: 12),
              _mapControl(LucideIcons.minus, false, onTap: _zoomOut),
              const SizedBox(height: 8),
              _mapControl(
                LucideIcons.locateFixed,
                true,
                onTap: _focusOnVisibleContent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController
      ..removeListener(_rebuildUserLocationPulse)
      ..dispose();
    _mapController?.dispose();
    _markersNotifier.dispose();
    _circlesNotifier.dispose();
    super.dispose();
  }
}
