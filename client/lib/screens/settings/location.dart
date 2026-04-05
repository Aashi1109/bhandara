import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/location_picker.dart';
import '../../models/user.dart';
import '../../providers/user.dart';
import '../../services/location_permission.dart';
import '../../services/maps/map_manager.dart';
import '../../services/maps/map_marker_factory.dart';
import '../../services/maps/map_models.dart';
import '../../services/maps/map_provider_type.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/map_view.dart';
import '../../widgets/settings_action_footer.dart';
import '../../widgets/snackbar.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({
    super.key,
    this.mode = LocationSelectionMode.settings,
    this.initialLocation,
    this.initialCameraLatitude,
    this.initialCameraLongitude,
    this.initialZoom,
    this.mapManager,
    this.currentLocationResolver,
    this.useStaticMapPlaceholder = false,
  });

  static const String routePath = '/settings/location';
  static const String _settingsRoutePath = '/settings';
  final LocationSelectionMode mode;
  final UserAddress? initialLocation;
  final double? initialCameraLatitude;
  final double? initialCameraLongitude;
  final double? initialZoom;
  final MapManager? mapManager;
  final Future<UserAddress?> Function()? currentLocationResolver;
  final bool useStaticMapPlaceholder;

  @override
  ConsumerState<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends ConsumerState<LocationSettingsScreen> {
  static const LatLng _defaultLocation = LatLng(21.1702, 79.6527);
  static const double _minZoom = 4;
  static const double _maxZoom = 20;
  static const double _zoomStep = 1;
  static const double _initialZoom = 14;

  late final MapManager _mapManager =
      widget.mapManager ?? MapManager(type: MapProviderType.google);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  GoogleMapController? _mapController;
  double _currentZoom = _initialZoom;
  LatLng _selectedLocation = _defaultLocation;
  LatLng _cameraTarget = _defaultLocation;
  LatLng _initialLocation = _defaultLocation;
  BitmapDescriptor? _selectedLocationMarkerIcon;
  String _selectedLabel = 'Not set';
  List<MapSearchSuggestion> _suggestions = const [];
  Timer? _debounce;
  bool _isSearching = false;
  bool _didHydrate = false;
  bool _isResolvingDraggedLocation = false;
  bool _isSearchOpen = false;

  Set<Factory<OneSequenceGestureRecognizer>> get _mapGestureRecognizers => {
    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
    Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
  };

  bool get _isPickerMode => widget.mode == LocationSelectionMode.picker;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon();
  }

  Future<void> _loadMarkerIcon() async {
    final icon = await MapMarkerFactory.createUserLocationMarker();
    if (!mounted) return;
    setState(() => _selectedLocationMarkerIcon = icon);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _hydrateFromUser() {
    if (_didHydrate) return;

    final seedLocation =
        widget.initialLocation ?? ref.read(userProfileProvider).value?.address;
    if (seedLocation == null) return;

    _selectedLabel = seedLocation.label;
    _selectedLocation = LatLng(
      seedLocation.latitude ?? _defaultLocation.latitude,
      seedLocation.longitude ?? _defaultLocation.longitude,
    );
    _cameraTarget = LatLng(
      widget.initialCameraLatitude ?? _selectedLocation.latitude,
      widget.initialCameraLongitude ?? _selectedLocation.longitude,
    );
    _currentZoom = widget.initialZoom ?? _initialZoom;
    _initialLocation = _selectedLocation;
    _searchController.text = _selectedLabel;
    _didHydrate = true;
  }

  bool get _isDirty {
    const epsilon = 0.000001;
    final latChanged =
        (_selectedLocation.latitude - _initialLocation.latitude).abs() >
        epsilon;
    final lngChanged =
        (_selectedLocation.longitude - _initialLocation.longitude).abs() >
        epsilon;
    return latChanged || lngChanged;
  }

  Future<void> _changeZoom(double delta) async {
    final controller = _mapController;
    if (controller == null) return;

    final nextZoom = (_currentZoom + delta)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    if (nextZoom == _currentZoom) return;

    _currentZoom = nextZoom;
    await controller.animateCamera(CameraUpdate.zoomTo(_currentZoom));
  }

  Future<void> _moveToLocation(
    LatLng target, {
    double zoom = _initialZoom,
  }) async {
    _currentZoom = zoom;
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
    if (mounted) {
      setState(() {
        _selectedLocation = target;
        _cameraTarget = target;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final resolved = widget.currentLocationResolver != null
          ? await widget.currentLocationResolver!()
          : await _resolveCurrentLocation();
      if (resolved == null || !mounted) return;

      setState(() {
        _selectedLocation = LatLng(
          resolved.latitude ?? _defaultLocation.latitude,
          resolved.longitude ?? _defaultLocation.longitude,
        );
        _cameraTarget = _selectedLocation;
        _selectedLabel = resolved.label;
        _searchController.text = _selectedLabel;
        _suggestions = const [];
      });
      await _moveToLocation(_selectedLocation);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Unable to get current location.',
        type: SnackBarType.error,
      );
    }
  }

  Future<UserAddress?> _resolveCurrentLocation() async {
    var status = await LocationPermissionService.currentStatus();
    if (!LocationPermissionService.hasAccess(status)) {
      status = await LocationPermissionService.requestOnStartup();
    }
    if (!LocationPermissionService.hasAccess(status)) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final address = await _mapManager.getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return UserAddress(
      label:
          address?.formattedAddress ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 3) {
      if (mounted) {
        setState(() => _suggestions = const []);
      }
      return;
    }

    setState(() => _isSearching = true);
    try {
      final suggestions = await _mapManager.searchPlaces(
        query: query,
        limit: 5,
      );
      if (!mounted) return;
      setState(() => _suggestions = suggestions);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectSuggestion(MapSearchSuggestion suggestion) async {
    final label = suggestion.subtitle?.isNotEmpty == true
        ? '${suggestion.title}, ${suggestion.subtitle}'
        : suggestion.title;
    double? latitude = suggestion.latitude;
    double? longitude = suggestion.longitude;

    if (latitude == null || longitude == null) {
      final matches = await _mapManager.getCoordinatesFromAddress(
        address: label,
        limit: 1,
      );
      if (matches.isEmpty) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: 'Unable to move to that location.',
          type: SnackBarType.error,
        );
        return;
      }
      latitude = matches.first.latitude;
      longitude = matches.first.longitude;
    }

    if (!mounted) return;
    final target = LatLng(latitude, longitude);
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = target;
      _cameraTarget = target;
      _selectedLabel = label;
      _searchController.text = _selectedLabel;
      _suggestions = const [];
    });
    await _moveToLocation(target);
  }

  Future<void> _handleMapIdle() async {
    if (_isResolvingDraggedLocation || widget.useStaticMapPlaceholder) return;

    _isResolvingDraggedLocation = true;
    try {
      final target = _cameraTarget;
      final address = await _mapManager.getAddressFromCoordinates(
        latitude: target.latitude,
        longitude: target.longitude,
      );
      if (!mounted) return;
      setState(() {
        _selectedLocation = target;
        _selectedLabel =
            address?.formattedAddress ??
            '${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)}';
        _searchController.text = _selectedLabel;
      });
    } finally {
      _isResolvingDraggedLocation = false;
    }
  }

  Future<void> _saveLocation() async {
    final selected = UserAddress(
      label: _selectedLabel,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
    );

    if (_isPickerMode) {
      if (!mounted) return;
      Navigator.of(context).pop(
        LocationPickerResult(
          location: selected,
          cameraLatitude: _cameraTarget.latitude,
          cameraLongitude: _cameraTarget.longitude,
          zoom: _currentZoom,
        ),
      );
      return;
    }

    final user = ref.read(userProfileProvider).value;
    if (user == null || !_isDirty) return;

    await ref.read(userProfileProvider.notifier).updateUserData({
      'address': selected.toJson(),
    });
    if (!mounted) return;
    AppSnackBar.success(context, 'Location saved.');
    context.go(LocationSettingsScreen._settingsRoutePath);
  }

  String? _distanceLabel(MapSearchSuggestion suggestion) {
    final latitude = suggestion.latitude;
    final longitude = suggestion.longitude;
    if (latitude == null || longitude == null) {
      return null;
    }

    final origin =
        widget.initialLocation ?? ref.read(userProfileProvider).value?.address;
    final originLatitude = origin?.latitude;
    final originLongitude = origin?.longitude;
    if (originLatitude == null || originLongitude == null) {
      return null;
    }

    final distanceInMeters = Geolocator.distanceBetween(
      originLatitude,
      originLongitude,
      latitude,
      longitude,
    );

    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }

    return '${distanceInMeters.round()} m';
  }

  void _openSearchOverlay() {
    setState(() {
      _isSearchOpen = true;
      _searchController.text = _selectedLabel;
      _searchController.selection = TextSelection(
        baseOffset: _searchController.text.length,
        extentOffset: _searchController.text.length,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearchOverlay() {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearchOpen = false;
      _isSearching = false;
      _suggestions = const [];
      _searchController.text = _selectedLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    _hydrateFromUser();
    final typography = context.appTypography;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: _isPickerMode ? 'Select Location' : 'Default Location',
            onBack: () => _isPickerMode
                ? context.pop()
                : context.go(LocationSettingsScreen._settingsRoutePath),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AbsorbPointer(
                            absorbing: _suggestions.isNotEmpty,
                            child: widget.useStaticMapPlaceholder
                                ? Container(color: AppColors.muted)
                                : AppMapView(
                                    manager: _mapManager,
                                    initialCameraPosition: CameraPosition(
                                      target: _cameraTarget,
                                      zoom: _currentZoom,
                                    ),
                                    markers: {
                                      if (_selectedLocationMarkerIcon != null)
                                        Marker(
                                          markerId: const MarkerId(
                                            'selected_location',
                                          ),
                                          position: _selectedLocation,
                                          anchor: const Offset(0.5, 1),
                                          icon: _selectedLocationMarkerIcon!,
                                        ),
                                    },
                                    gestureRecognizers: _suggestions.isEmpty
                                        ? _mapGestureRecognizers
                                        : const <
                                            Factory<
                                              OneSequenceGestureRecognizer
                                            >
                                          >{},
                                    onMapReady: (controller) {
                                      _mapController = controller;
                                    },
                                    onCameraMove: (position) {
                                      _currentZoom = position.zoom;
                                      _cameraTarget = position.target;
                                    },
                                    onCameraIdle: _handleMapIdle,
                                  ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          top: 24,
                          left: 24,
                          right: _isSearchOpen ? 24 : 88,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child: _isSearchOpen
                                ? Material(
                                    key: const ValueKey('location-search-open'),
                                    color: AppColors.transparent,
                                    child: _buildSearchBar(),
                                  )
                                : GestureDetector(
                                    key: const ValueKey(
                                      'location-search-closed',
                                    ),
                                    onTap: _openSearchOverlay,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.search,
                                            size: AppIconSizes.s,
                                            color: AppColors.mutedForeground,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _isSearching
                                                  ? 'Searching...'
                                                  : _selectedLabel,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: typography.bodySMStrong
                                                  .copyWith(
                                                    color: AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (_isSearchOpen) ...[
                          Positioned.fill(
                            top: 84,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _closeSearchOverlay,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                        if (_suggestions.isNotEmpty) ...[
                          Positioned(
                            top: 84,
                            left: 24,
                            right: 24,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              offset: Offset.zero,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: 1,
                                child: Material(
                                  color: AppColors.transparent,
                                  elevation: 24,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {},
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 180,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: _suggestions.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(
                                              height: 1,
                                              color: AppColors.border,
                                            ),
                                        itemBuilder: (context, index) {
                                          final suggestion =
                                              _suggestions[index];
                                          final distanceLabel = _distanceLabel(
                                            suggestion,
                                          );
                                          final details = <String>[];
                                          final subtitle = suggestion.subtitle
                                              ?.trim();
                                          if (subtitle != null &&
                                              subtitle.isNotEmpty) {
                                            details.add(subtitle);
                                          }
                                          if (distanceLabel != null) {
                                            details.add(distanceLabel);
                                          }
                                          return Material(
                                            color: AppColors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                await _selectSuggestion(
                                                  suggestion,
                                                );
                                                if (!mounted) return;
                                                _closeSearchOverlay();
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      suggestion.title,
                                                      style: typography.labelMD
                                                          .copyWith(
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                    ),
                                                    if ((suggestion.subtitle !=
                                                                null &&
                                                            suggestion
                                                                .subtitle!
                                                                .isNotEmpty) ||
                                                        distanceLabel !=
                                                            null) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        details.join(' • '),
                                                        style: typography.bodySM
                                                            .copyWith(
                                                              color: AppColors
                                                                  .mutedForeground,
                                                            ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: Column(
                            children: [
                              _mapControl(
                                LucideIcons.plus,
                                onTap: () => _changeZoom(_zoomStep),
                              ),
                              const SizedBox(height: 12),
                              _mapControl(
                                LucideIcons.minus,
                                onTap: () => _changeZoom(-_zoomStep),
                              ),
                              const SizedBox(height: 12),
                              _mapControl(
                                LucideIcons.locateFixed,
                                onTap: _useCurrentLocation,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SettingsActionFooter(
            label: _isPickerMode ? 'Use This Location' : 'Confirm Location',
            loadable: true,
            onPressed: _isPickerMode || _isDirty ? _saveLocation : null,
          ),
        ],
      ),
    );
  }

  Widget _mapControl(IconData icon, {required VoidCallback onTap}) {
    final isPrimary = icon == LucideIcons.locateFixed;
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

  Widget _buildSearchBar() {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.search,
              size: AppIconSizes.defaultSize,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 350),
                    () => _searchAddress(value),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Search address or area',
                  hintStyle: typography.bodyMD.copyWith(
                    color: AppColors.mutedForeground.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                style: typography.bodyMD.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
