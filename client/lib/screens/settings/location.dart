import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/user.dart';
import '../../services/location_permission.dart';
import '../../services/maps/map_manager.dart';
import '../../services/maps/map_models.dart';
import '../../services/maps/map_provider_type.dart';
import '../../theme/theme.dart';
import '../../widgets/button.dart';
import '../../widgets/header.dart';
import '../../widgets/input.dart';
import '../../widgets/map_view.dart';
import '../../widgets/snackbar.dart';
import '../settings.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({super.key});

  static const String routePath = '/settings/location';

  @override
  ConsumerState<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends ConsumerState<LocationSettingsScreen> {
  late final MapManager _mapManager = MapManager(type: MapProviderType.google);

  static const LatLng _defaultLocation = LatLng(21.1702, 79.6527);
  static const double _minZoom = 4;
  static const double _maxZoom = 20;
  static const double _zoomStep = 1;
  static const double _initialZoom = 14;

  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  double _currentZoom = _initialZoom;
  LatLng _selectedLocation = _defaultLocation;
  LatLng _initialLocation = _defaultLocation;
  String _selectedLabel = 'Not set';
  String _initialLabel = 'Not set';
  List<MapSearchSuggestion> _suggestions = const [];
  Timer? _debounce;
  bool _isSearching = false;
  bool _didHydrate = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _hydrateFromUser() {
    final user = ref.read(userProfileProvider).value;
    if (_didHydrate || user?.address == null) return;

    _selectedLabel = user!.address!.label;
    _selectedLocation = LatLng(
      user.address!.latitude ?? _defaultLocation.latitude,
      user.address!.longitude ?? _defaultLocation.longitude,
    );
    _initialLocation = _selectedLocation;
    _initialLabel = _selectedLabel;
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
    return latChanged || lngChanged || _selectedLabel != _initialLabel;
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
      });
    }
  }

  Future<void> _centerMap() async {
    await _moveToLocation(_selectedLocation, zoom: _initialZoom);
  }

  Future<void> _useCurrentLocation() async {
    var status = await LocationPermissionService.currentStatus();
    if (!LocationPermissionService.hasAccess(status)) {
      status = await LocationPermissionService.requestOnStartup();
    }
    if (!LocationPermissionService.hasAccess(status)) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final address = await _mapManager.getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (!mounted) return;
    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _selectedLabel =
          address?.formattedAddress ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      _searchController.text = _selectedLabel;
      _suggestions = const [];
    });
    await _moveToLocation(_selectedLocation);
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
    if (suggestion.latitude == null || suggestion.longitude == null) return;
    final target = LatLng(suggestion.latitude!, suggestion.longitude!);
    setState(() {
      _selectedLabel = suggestion.subtitle?.isNotEmpty == true
          ? '${suggestion.title}, ${suggestion.subtitle}'
          : suggestion.title;
      _searchController.text = _selectedLabel;
      _suggestions = const [];
    });
    await _moveToLocation(target);
  }

  Future<void> _saveLocation() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null || !_isDirty) return;

    await ref.read(userProfileProvider.notifier).updateUserData({
      'address': {
        'address': _selectedLabel,
        'coordinates': {
          'latitude': _selectedLocation.latitude,
          'longitude': _selectedLocation.longitude,
        },
      },
    });
    if (!mounted) return;
    AppSnackBar.success(context, 'Location saved.');
    context.go(SettingsScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    _hydrateFromUser();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Default Location',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  AppInput(
                    placeholder: 'Search address or area',
                    icon: const Icon(LucideIcons.search),
                    height: 56,
                    borderRadius: 16,
                    controller: _searchController,
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 350),
                        () => _searchAddress(value),
                      );
                    },
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            title: Text(suggestion.title),
                            subtitle: suggestion.subtitle != null
                                ? Text(suggestion.subtitle!)
                                : null,
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    icon: const Icon(
                      LucideIcons.locateFixed,
                      size: AppIconSizes.defaultSize,
                    ),
                    label: 'Use Current Location',
                    onPressed: _useCurrentLocation,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          AppMapView(
                            manager: _mapManager,
                            initialCameraPosition: CameraPosition(
                              target: _selectedLocation,
                              zoom: _initialZoom,
                            ),
                            markers: const <Marker>{},
                            onMapReady: (controller) {
                              _mapController = controller;
                            },
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.surface,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        LucideIcons.mapPin,
                                        size: AppIconSizes.defaultSize,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 24,
                            left: 24,
                            right: 24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                _isSearching ? 'Searching...' : _selectedLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
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
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 24,
                            left: 24,
                            child: _mapControl(
                              LucideIcons.locateFixed,
                              onTap: _centerMap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: AppButton(
              size: AppButtonSize.xl,
              fullWidth: true,
              label: 'Confirm Location',
              loadable: true,
              onPressed: _isDirty ? _saveLocation : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapControl(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: AppIconSizes.defaultSize,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
