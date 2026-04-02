import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/event.dart';
import '../../../services/maps/map_manager.dart';
import '../../../services/maps/map_marker_factory.dart';
import '../../../theme/theme.dart';
import '../models/event_cluster.dart' as models;
import '../models/event_marker.dart';
import '../utils/explore_viewport.dart';
import '../../../widgets/map_view.dart';

class ExploreEventMap extends StatefulWidget {
  const ExploreEventMap({
    super.key,
    required this.manager,
    this.events = const [],
    this.eventMarkers = const [],
    this.serverClusters = const [],
    this.selectedEvent,
    this.selectedMarkerId,
    required this.userLocation,
    this.onEventSelected,
    this.onMarkerSelected,
    required this.safeAreaPadding,
    required this.shouldAutoFitOnContentChange,
    required this.selectedEventFocusRequestId,
    this.onClusterFocusStart,
    this.onViewportChanged,
    this.onRecenterRequested,
    this.useServerClusters = false,
  });

  final MapManager manager;
  final List<Event> events;
  final List<EventMarker> eventMarkers;
  final List<models.EventCluster> serverClusters;
  final Event? selectedEvent;
  final String? selectedMarkerId;
  final LatLng? userLocation;
  final ValueChanged<Event>? onEventSelected;
  final ValueChanged<String>? onMarkerSelected;
  final EdgeInsets safeAreaPadding;
  final bool shouldAutoFitOnContentChange;
  final int selectedEventFocusRequestId;
  final VoidCallback? onClusterFocusStart;
  final ValueChanged<ExploreViewportQuery>? onViewportChanged;
  final VoidCallback? onRecenterRequested;
  final bool useServerClusters;

  @override
  State<ExploreEventMap> createState() => _ExploreEventMapState();
}

class _ExploreEventMapState extends State<ExploreEventMap>
    with SingleTickerProviderStateMixin {
  static const double _initialZoom = 11;
  static const double _userPulseMinRadius = 30;
  static const double _userPulseMaxRadius = 120;
  static const double _fitBoundsInset = 72;
  static const double _viewportEdgeBuffer = 16;

  final _MarkerClusterer _markerClusterer = const _MarkerClusterer();
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
  Timer? _viewportDebounce;
  ExploreViewportQuery? _lastEmittedViewport;
  Size _mapSize = Size.zero;
  double _mapZoom = _initialZoom;
  double _pendingZoom = _initialZoom;
  bool _isProgrammaticCameraMove = false;
  bool _didUserMoveCamera = false;

  /// When > 0, _handleCameraIdle is suppressed entirely. Used by
  /// _animateCameraAndEmitViewport to prevent mid-animation idle
  /// callbacks from interfering with the forced viewport emission.
  int _suppressIdleCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(_rebuildUserLocationPulse)
          ..repeat();
    _loadMarkerIcons();
    _rebuildMapMarkers();
    _rebuildUserLocationPulse();
  }

  @override
  void didUpdateWidget(covariant ExploreEventMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final eventsChanged = oldWidget.events != widget.events;
    final markersChanged = oldWidget.eventMarkers != widget.eventMarkers;
    final clustersChanged = oldWidget.serverClusters != widget.serverClusters;
    final locationChanged = oldWidget.userLocation != widget.userLocation;
    final safeAreaChanged = oldWidget.safeAreaPadding != widget.safeAreaPadding;
    final modeChanged = oldWidget.useServerClusters != widget.useServerClusters;
    final selectionChanged =
        oldWidget.selectedEvent?.id != widget.selectedEvent?.id ||
        oldWidget.selectedMarkerId != widget.selectedMarkerId;

    if (eventsChanged ||
        markersChanged ||
        clustersChanged ||
        selectionChanged ||
        locationChanged ||
        modeChanged) {
      debugPrint(
        '[MAP] _rebuildMapMarkers: events=$eventsChanged markers=$markersChanged clusters=$clustersChanged selection=$selectionChanged location=$locationChanged mode=$modeChanged useServerClusters=${widget.useServerClusters} clusterCount=${widget.serverClusters.length} markerCount=${widget.eventMarkers.length}',
      );
      _rebuildMapMarkers();
      if (locationChanged) {
        _rebuildUserLocationPulse();
      }
    }

    if (widget.selectedEvent != null &&
        oldWidget.selectedEventFocusRequestId !=
            widget.selectedEventFocusRequestId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_focusOnSelectedEvent());
      });
    }

    if (safeAreaChanged && widget.selectedEvent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_focusOnSelectedEvent());
      });
    }

    if ((eventsChanged || locationChanged || safeAreaChanged) &&
        widget.shouldAutoFitOnContentChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_fitCameraToVisibleContent());
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

    if (widget.eventMarkers.isNotEmpty) {
      return widget.eventMarkers.first.position;
    }

    if (widget.serverClusters.isNotEmpty) {
      return widget.serverClusters.first.position;
    }

    return const LatLng(21.1458, 79.0882);
  }

  void _rebuildMapMarkers() {
    final markers = _buildMarkers();
    debugPrint(
      '[MAP] _rebuildMapMarkers OUTPUT: ${markers.length} markers (useServerClusters=${widget.useServerClusters} clusterInput=${widget.serverClusters.length} markerInput=${widget.eventMarkers.length})',
    );
    _markersNotifier.value = markers;
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
    if (widget.useServerClusters) {
      return _buildServerClusterMarkers();
    }
    if (widget.eventMarkers.isNotEmpty) {
      return _buildEventMarkerPins();
    }
    // No data yet — just show user location if available.
    final markers = <Marker>{};
    _addUserLocationMarker(markers);
    return markers;
  }

  Set<Marker> _buildServerClusterMarkers() {
    final markers = <Marker>{};

    for (final cluster in widget.serverClusters) {
      markers.add(
        Marker(
          markerId: MarkerId(
            'scluster_${cluster.latitude}_${cluster.longitude}_${cluster.count}',
          ),
          position: cluster.position,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          icon: _resolveClusterMarker(cluster.count),
          onTap: () => _focusOnServerCluster(cluster),
        ),
      );
    }

    _addUserLocationMarker(markers);
    return markers;
  }

  Set<Marker> _buildEventMarkerPins() {
    final markers = <Marker>{};
    final clusters = _markerClusterer.clusterMarkers(
      widget.eventMarkers,
      zoom: _mapZoom,
    );

    for (final cluster in clusters) {
      if (cluster.isCluster) {
        markers.add(
          Marker(
            markerId: MarkerId(
              'cluster_${cluster.center.latitude}_${cluster.center.longitude}_${cluster.count}',
            ),
            position: cluster.center,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
            icon: _resolveClusterMarker(cluster.count),
            onTap: () => _focusOnMarkerCluster(cluster),
          ),
        );
        continue;
      }

      final marker = cluster.primaryMarker;
      final isSelected = widget.selectedMarkerId == marker.id;
      final eventIcon = isSelected
          ? _selectedEventMarkerIcon
          : _eventMarkerIcon;
      if (eventIcon == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(marker.id),
          position: marker.position,
          icon: eventIcon,
          infoWindow: InfoWindow(title: marker.name),
          onTap: () => widget.onMarkerSelected?.call(marker.id),
        ),
      );
    }

    _addUserLocationMarker(markers);
    return markers;
  }

  void _addUserLocationMarker(Set<Marker> markers) {
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
  }

  BitmapDescriptor _resolveClusterMarker(int count) {
    final cached = _clusterMarkerCache[count];
    if (cached != null) return cached;

    if (!_pendingClusterIcons.contains(count)) {
      _pendingClusterIcons.add(count);
      MapMarkerFactory.createClusterMarker(count: count).then((icon) {
        if (!mounted) return;
        _clusterMarkerCache[count] = icon;
        _pendingClusterIcons.remove(count);
        _rebuildMapMarkers();
      });
    }

    // Return default marker while the custom icon loads so the
    // marker is always visible on the map — never skip it.
    return BitmapDescriptor.defaultMarker;
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

    for (final marker in widget.eventMarkers) {
      points.add(marker.position);
    }

    for (final cluster in widget.serverClusters) {
      points.add(cluster.position);
    }

    return points;
  }

  Future<void> _fitCameraToVisibleContent() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = _contentPoints();
    if (points.isEmpty) {
      await _runProgrammaticCameraMove(
        CameraUpdate.newLatLngZoom(_getInitialMapCenter(), _initialZoom),
      );
      return;
    }

    if (points.length == 1) {
      await _runProgrammaticCameraMove(
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

    await _runProgrammaticCameraMove(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        _fitBoundsInset,
      ),
    );
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (controller == null) return;
    final zoom = await controller.getZoomLevel();
    await _runProgrammaticCameraMove(
      CameraUpdate.zoomTo((zoom + 1).clamp(2, 20).toDouble()),
    );
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (controller == null) return;
    final zoom = await controller.getZoomLevel();
    await _runProgrammaticCameraMove(
      CameraUpdate.zoomTo((zoom - 1).clamp(2, 20).toDouble()),
    );
  }

  Future<void> _focusOnVisibleContent() async {
    widget.onRecenterRequested?.call();
    await _fitCameraToVisibleContent();
  }

  Future<void> _focusOnServerCluster(models.EventCluster cluster) async {
    widget.onClusterFocusStart?.call();
    // Zoom in incrementally (by 2 levels) instead of jumping straight to
    // tile zoom. This keeps the map in cluster mode so markers refine
    // progressively rather than vanishing during a cluster→tile transition.
    final targetZoom = (_mapZoom + 2).clamp(4.0, 20.0);
    await _animateCameraAndEmitViewport(
      CameraUpdate.newLatLngZoom(cluster.position, targetZoom),
    );
  }

  Future<void> _focusOnMarkerCluster(_EventMarkerCluster cluster) async {
    widget.onClusterFocusStart?.call();
    await _animateCameraAndEmitViewport(
      CameraUpdate.newLatLngZoom(cluster.center, (_mapZoom + 2).clamp(4, 20)),
    );
  }

  /// Moves the camera AND triggers a viewport change emission afterward.
  /// Use this for user-initiated actions (cluster tap, marker cluster tap)
  /// where we need the parent to refetch data for the new viewport.
  ///
  /// Suppresses all _handleCameraIdle processing during the animation to
  /// prevent mid-animation idle callbacks from creating races.
  Future<void> _animateCameraAndEmitViewport(CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;

    _viewportDebounce?.cancel();
    _suppressIdleCount++;
    _isProgrammaticCameraMove = true;
    _didUserMoveCamera = false;
    try {
      await controller.animateCamera(update);
    } catch (_) {
      _suppressIdleCount--;
      _isProgrammaticCameraMove = false;
      return;
    }
    _suppressIdleCount--;
    _isProgrammaticCameraMove = false;
    _didUserMoveCamera = false;
    _viewportDebounce?.cancel();

    // Sync zoom — _handleCameraIdle was suppressed so _mapZoom is stale.
    _mapZoom = _pendingZoom;

    // Force emit viewport change so the parent loads data for the new position.
    await _emitViewportChanged(force: true);
  }

  Future<void> _focusOnSelectedEvent() async {
    final controller = _mapController;
    final selectedEvent = widget.selectedEvent;
    final lat = selectedEvent?.location.latitude;
    final lng = selectedEvent?.location.longitude;
    if (controller == null || lat == null || lng == null) {
      return;
    }

    await _runProgrammaticCameraMove(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  Future<void> _runProgrammaticCameraMove(CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;

    _viewportDebounce?.cancel();
    _isProgrammaticCameraMove = true;
    try {
      await controller.animateCamera(update);
    } catch (_) {
      _isProgrammaticCameraMove = false;
      rethrow;
    }
  }

  void _handleCameraMoveStarted() {
    if (_isProgrammaticCameraMove) {
      return;
    }
    _didUserMoveCamera = true;
    // Cancel any pending viewport emission — the user is still panning.
    _viewportDebounce?.cancel();
  }

  void _handleCameraIdle() {
    if (!mounted) return;

    // When a controlled animation is in progress, skip all idle processing.
    // The animation owner will sync zoom and emit viewport itself.
    if (_suppressIdleCount > 0) return;

    final nextZoom = _pendingZoom;
    if ((nextZoom - _mapZoom).abs() >= 0.05) {
      setState(() {
        _mapZoom = nextZoom;
      });
      _rebuildMapMarkers();
    }

    if (_isProgrammaticCameraMove) {
      _isProgrammaticCameraMove = false;
      _didUserMoveCamera = false;
      return;
    }

    if (!_didUserMoveCamera) {
      return;
    }

    _didUserMoveCamera = false;
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      unawaited(_emitViewportChanged());
    });
  }

  Future<void> _emitViewportChanged({bool force = false}) async {
    final controller = _mapController;
    if (controller == null || _mapSize.isEmpty) {
      return;
    }

    final safeViewport = _safeViewportRect(_mapSize, widget.safeAreaPadding);
    if (safeViewport.width <= 0 || safeViewport.height <= 0) {
      return;
    }

    final centerPoint = _screenCoordinate(safeViewport.center);
    final cornerPoints = <ScreenCoordinate>[
      _screenCoordinate(safeViewport.topLeft),
      _screenCoordinate(Offset(safeViewport.right, safeViewport.top)),
      _screenCoordinate(Offset(safeViewport.left, safeViewport.bottom)),
      _screenCoordinate(safeViewport.bottomRight),
    ];

    final center = await controller.getLatLng(centerPoint);
    final corners = await Future.wait(cornerPoints.map(controller.getLatLng));
    final viewport = ExploreViewportQuery(
      center: center,
      radiusKm: viewportRadiusKmFromCorners(center: center, corners: corners),
      zoom: _mapZoom,
    );

    if (!force &&
        !hasMeaningfulViewportChange(_lastEmittedViewport, viewport)) {
      return;
    }

    debugPrint(
      '[MAP] emitViewportChanged zoom=${viewport.zoom.toStringAsFixed(1)} center=${viewport.center.latitude.toStringAsFixed(4)},${viewport.center.longitude.toStringAsFixed(4)} radius=${viewport.radiusKm.toStringAsFixed(1)}km force=$force',
    );
    _lastEmittedViewport = viewport;
    widget.onViewportChanged?.call(viewport);
  }

  Rect _safeViewportRect(Size mapSize, EdgeInsets padding) {
    final left = (padding.left + _viewportEdgeBuffer).clamp(0.0, mapSize.width);
    final top = (padding.top + _viewportEdgeBuffer).clamp(0.0, mapSize.height);
    final right = max(
      left + 1,
      mapSize.width -
          (padding.right + _viewportEdgeBuffer).clamp(0.0, mapSize.width),
    );
    final bottom = max(
      top + 1,
      mapSize.height -
          (padding.bottom + _viewportEdgeBuffer).clamp(0.0, mapSize.height),
    );

    return Rect.fromLTRB(left, top, right, bottom);
  }

  ScreenCoordinate _screenCoordinate(Offset offset) {
    return ScreenCoordinate(x: offset.dx.round(), y: offset.dy.round());
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final nextSize = constraints.biggest;
              if (_mapSize != nextSize) {
                _mapSize = nextSize;
              }

              return ValueListenableBuilder<Set<Marker>>(
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
                        padding: widget.safeAreaPadding,
                        onMapReady: (controller) {
                          _mapController = controller;
                          if (widget.shouldAutoFitOnContentChange) {
                            Future<void>.delayed(
                              const Duration(milliseconds: 250),
                              () async {
                                if (!mounted) return;
                                await _fitCameraToVisibleContent();
                              },
                            );
                          }
                        },
                        onCameraMoveStarted: _handleCameraMoveStarted,
                        onCameraMove: (position) =>
                            _pendingZoom = position.zoom,
                        onCameraIdle: _handleCameraIdle,
                      );
                    },
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
    _viewportDebounce?.cancel();
    _pulseController
      ..removeListener(_rebuildUserLocationPulse)
      ..dispose();
    _mapController?.dispose();
    _markersNotifier.dispose();
    _circlesNotifier.dispose();
    super.dispose();
  }
}

class _EventMarkerCluster {
  _EventMarkerCluster({required this.center, required this.markers});

  final LatLng center;
  final List<EventMarker> markers;

  bool get isCluster => markers.length > 1;

  EventMarker get primaryMarker => markers.first;

  int get count => markers.length;
}

class _MarkerClusterer {
  const _MarkerClusterer();

  List<_EventMarkerCluster> clusterMarkers(
    List<EventMarker> markers, {
    required double zoom,
    double clusterRadius = 88,
  }) {
    if (markers.isEmpty) return const [];

    final worldSize = 256 * pow(2, zoom).toDouble();
    final projected = <_ProjectedMarker>[];

    for (final marker in markers) {
      projected.add(
        _ProjectedMarker(
          marker: marker,
          point: _project(marker.latitude, marker.longitude, worldSize),
        ),
      );
    }

    final visited = <int>{};
    final clusters = <_EventMarkerCluster>[];

    for (var i = 0; i < projected.length; i++) {
      if (visited.contains(i)) continue;

      final queue = <int>[i];
      final clusterMarkers = <EventMarker>[];
      var sumLat = 0.0;
      var sumLng = 0.0;

      while (queue.isNotEmpty) {
        final currentIndex = queue.removeLast();
        if (!visited.add(currentIndex)) continue;

        final current = projected[currentIndex];
        clusterMarkers.add(current.marker);
        sumLat += current.marker.latitude;
        sumLng += current.marker.longitude;

        for (var j = 0; j < projected.length; j++) {
          if (visited.contains(j) || currentIndex == j) continue;
          if ((current.point - projected[j].point).magnitude <= clusterRadius) {
            queue.add(j);
          }
        }
      }

      clusters.add(
        _EventMarkerCluster(
          center: LatLng(
            sumLat / clusterMarkers.length,
            sumLng / clusterMarkers.length,
          ),
          markers: clusterMarkers,
        ),
      );
    }

    clusters.sort((a, b) => b.count.compareTo(a.count));
    return clusters;
  }

  Point<double> _project(double lat, double lng, double worldSize) {
    final x = (lng + 180) / 360 * worldSize;
    final sinLat = sin(lat * pi / 180).clamp(-0.9999, 0.9999);
    final y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) * worldSize;
    return Point<double>(x, y);
  }
}

class _ProjectedMarker {
  const _ProjectedMarker({required this.marker, required this.point});

  final EventMarker marker;
  final Point<double> point;
}
