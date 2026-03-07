import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';

import '../settings.dart';

class LocationSettingsScreen extends StatelessWidget {
  static const String routePath = '/settings/location';
  const LocationSettingsScreen({super.key});

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
                          ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              AppColors.mutedForeground,
                              BlendMode.saturation,
                            ),
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://picsum.photos/seed/map-detail/800/800',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
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
                                _mapControl(LucideIcons.plus),
                                const SizedBox(height: 12),
                                _mapControl(LucideIcons.minus),
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

  Widget _mapControl(IconData icon) {
    return Container(
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
    );
  }
}
