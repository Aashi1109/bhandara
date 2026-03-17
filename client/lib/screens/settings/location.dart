import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/maps/map_manager.dart';
import '../../services/maps/map_provider_type.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../widgets/map_view.dart';

import '../settings.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  static const String routePath = '/settings/location';

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  late final MapManager _mapManager = MapManager(type: MapProviderType.google);

  static const LatLng _defaultLocation = LatLng(21.1702, 79.6527);
  static const double _minZoom = 4;
  static const double _maxZoom = 20;
  static const double _zoomStep = 1;
  static const double _initialZoom = 14;

  GoogleMapController? _mapController;
  double _currentZoom = _initialZoom;

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

  Future<void> _centerMap() async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _defaultLocation, zoom: _initialZoom),
      ),
    );
    _currentZoom = _initialZoom;
  }

  @override
  Widget build(BuildContext context) {
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
                  const AppInput(
                    placeholder: 'Search address or area',
                    icon: Icon(LucideIcons.search),
                    height: 56,
                    borderRadius: 16,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    icon: const Icon(LucideIcons.locateFixed, size: 20),
                    label: 'Use Current Location',
                    onPressed: () {},
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
                            initialCameraPosition: const CameraPosition(
                              target: _defaultLocation,
                              zoom: _initialZoom,
                            ),
                            markers: {
                              const Marker(
                                markerId: MarkerId('default_location'),
                                position: _defaultLocation,
                              ),
                            },
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
                                        size: 20,
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
              onPressed: () {},
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
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
