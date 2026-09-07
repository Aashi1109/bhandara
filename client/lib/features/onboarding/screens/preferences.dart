import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/map_view.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/providers/tag.dart';
import '../../../shared/providers/user.dart';
import '../../../shared/providers/user_settings.dart';
import '../../events/models/event.dart';
import '../../../shared/services/location_permission.dart';
import '../../../shared/services/maps/map_manager.dart';
import '../../../shared/services/maps/map_marker_factory.dart';
import '../../../shared/services/maps/map_provider_type.dart';

import '../../auth/screens/auth.dart';
import '../../explore/screens/explore_screen.dart';
import '../../settings/screens/location.dart';
import '../../../shared/models/location_picker.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  static const String routePath = '/preferences';

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  static const LatLng _fallbackLocation = LatLng(37.7749, -122.4194);
  final _selected = <String>{};
  final _expanded = <String>{};
  final MapManager _mapManager = MapManager(type: MapProviderType.google);
  GoogleMapController? _mapController;
  LatLng _selectedLocation = _fallbackLocation;
  String _locationLabel = 'San Francisco, CA';
  bool _isLocating = false;
  bool _isSaving = false;
  bool _didHydrateFromProfile = false;
  BitmapDescriptor? _locationMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon();
    _useCurrentLocation();
  }

  Future<void> _loadMarkerIcon() async {
    final icon = await MapMarkerFactory.createUserLocationMarker();
    if (!mounted) return;
    setState(() => _locationMarkerIcon = icon);
  }

  void _hydrateFromUser() {
    final user = ref.read(userProfileProvider).value;
    if (_didHydrateFromProfile || user == null) return;

    final interests = ref.read(userSettingsProvider).value?.interests ?? const <String>[];
    _selected.addAll(interests);

    if (user.address != null) {
      _selectedLocation = LatLng(
        user.address!.latitude ?? _fallbackLocation.latitude,
        user.address!.longitude ?? _fallbackLocation.longitude,
      );
      _locationLabel = user.address!.label.isNotEmpty
          ? user.address!.label
          : _locationLabel;
    }

    _didHydrateFromProfile = true;
  }

  void _toggle(Tag tag, List<Tag>? children) {
    setState(() {
      if (children != null && children.isNotEmpty) {
        // Parent toggle logic
        final allChildrenIds = children.map((c) => c.id).toSet();
        final selectedChildrenCount = children
            .where((c) => _selected.contains(c.id))
            .length;

        if (selectedChildrenCount == children.length) {
          // All selected -> deselect all
          _selected.removeAll(allChildrenIds);
          _selected.remove(tag.id);
        } else {
          // None or intermediate -> select all
          _selected.addAll(allChildrenIds);
          _selected.add(tag.id);
        }
      } else {
        // Leaf toggle logic
        if (_selected.contains(tag.id)) {
          _selected.remove(tag.id);
        } else {
          _selected.add(tag.id);
        }

        // Update parent state if it's a child
        if (tag.parentId != null) {
          // We don't have direct access to siblings here,
          // but we can let the parent widget handle its own "intermediate" visually
        }
      }
    });
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      var status = await LocationPermissionService.currentStatus();
      if (!LocationPermissionService.hasAccess(status)) {
        status = await LocationPermissionService.requestOnStartup();
      }

      final hasAccess = LocationPermissionService.hasAccess(status);
      if (!hasAccess) {
        if (mounted) {
          setState(() {
            _isLocating = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _mapManager.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _selectedLocation = latLng;
        _locationLabel = address?.formattedAddress.isNotEmpty == true
            ? address!.formattedAddress
            : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _isLocating = false;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 13),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLocating = false);
    }
  }

  Widget _buildTagLoadingState() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(
        8,
        (index) => AppSkeleton(
          width: index.isEven ? 112 : 88,
          height: 40,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _hydrateFromUser();
    final tagsAsync = ref.watch(tagsProvider(rootOnly: true));

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Preferences',
            onBack: () => context.pop(),
            rightElement: GestureDetector(
              onTap: () => context.go(ExploreScreen.routePath),
              child: Text(
                'Skip',
                style: context.appTypography.labelMD.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    "Let's set up your preferences",
                    style: context.appTypography.titleXL.copyWith(
                      color: context.appPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customize your feed to see the free food events you actually care about.',
                    style: context.appTypography.bodyLG.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'What do you like?',
                    style: context.appTypography.titleMD.copyWith(
                      color: context.appPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  tagsAsync.when(
                    data: (tags) {
                      if (tags.isEmpty) {
                        return const Center(child: Text('No categories found'));
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: tags.map((tag) {
                          return TagHierarchy(
                            tag: tag,
                            selected: _selected,
                            expanded: _expanded,
                            onToggle: _toggle,
                            onToggleExpanded: _toggleExpanded,
                          );
                        }).toList(),
                      );
                    },
                    loading: _buildTagLoadingState,
                    error: (err, stack) => Center(
                      child: Text(
                        'Failed to load categories: ${err.toString()}',
                        style: context.appTypography.bodyMD.copyWith(
                          color: context.appPalette.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // ... (Location section remains same)
                  _buildLocationSection(),
                ],
              ),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationSettingsScreen(
          mode: LocationSelectionMode.picker,
          initialLocation: null,
          initialCameraLatitude: _selectedLocation.latitude,
          initialCameraLongitude: _selectedLocation.longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(
          result.cameraLatitude,
          result.cameraLongitude,
        );
        _locationLabel = result.location.label.isNotEmpty
            ? result.location.label
            : _locationLabel;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, result.zoom),
      );
    }
  }

  Widget _buildLocationSection() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Set Your Base Location',
              style: context.appTypography.titleMD,
            ),
            GestureDetector(
              onTap: _useCurrentLocation,
              child: Text(
                'Use Current Location',
                style: context.appTypography.bodySMStrong.copyWith(
                  color: context.appPalette.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.appPalette.border),
              borderRadius: BorderRadius.circular(24),
              color: context.appPalette.muted,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 176,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      AppMapView(
                        manager: _mapManager,
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation,
                          zoom: 12,
                        ),
                        onMapReady: (controller) {
                          _mapController = controller;
                        },
                        markers: {
                          if (_locationMarkerIcon != null)
                            Marker(
                              markerId: const MarkerId('preferences-location'),
                              position: _selectedLocation,
                              anchor: const Offset(0.5, 1),
                              icon: _locationMarkerIcon!,
                            ),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        myLocationEnabled: false,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: context.appPalette.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'CURRENT SELECTION',
                              style: context.appTypography.overline.copyWith(
                                color: context.appPalette.mutedForeground,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _openLocationPicker,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.appPalette.muted,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.edit2,
                                size: AppIconSizes.m,
                                color: context.appPalette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: context.appPalette.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLocating
                                  ? 'Detecting location...'
                                  : _locationLabel.isNotEmpty
                                      ? _locationLabel
                                      : 'Location unavailable',
                              style: context.appTypography.bodySM.copyWith(
                                color: context.appPalette.primary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'We use this to show you events nearby. You can always change this in your profile settings later.',
            style: context.appTypography.bodyXS.copyWith(
              color: context.appPalette.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appPalette.surface.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: context.appPalette.border)),
      ),
      child: AppButton(
        size: AppButtonSize.lg,
        fullWidth: true,
        label: _isSaving ? 'Saving...' : 'Complete Setup',
        iconRight: const Icon(LucideIcons.arrowRight),
        onPressed: _isSaving
            ? null
            : () async {
                final user = ref.read(userProfileProvider).value;
                if (user == null) {
                  context.go(AuthScreen.routePath);
                  return;
                }

                setState(() => _isSaving = true);
                try {
                  await Future.wait([
                    ref.read(userSettingsProvider.notifier).updateSettings(
                      user.id,
                      {
                        'interests': _selected.toList(),
                        'onboarding': {'hasOnboarded': true},
                      },
                    ),
                    ref.read(userProfileProvider.notifier).updateUserData({
                      'address': {
                        'address': _locationLabel,
                        'coordinates': {
                          'latitude': _selectedLocation.latitude,
                          'longitude': _selectedLocation.longitude,
                        },
                      },
                    }),
                  ]);

                  if (!mounted) return;
                  context.go(ExploreScreen.routePath);
                } catch (_) {
                  // Error snackbar already shown by BaseService.throwError.
                  // Catch here only to block navigation on failure.
                } finally {
                  if (mounted) {
                    setState(() => _isSaving = false);
                  }
                }
              },
      ),
    );
  }
}

class TagHierarchy extends ConsumerWidget {
  const TagHierarchy({
    super.key,
    required this.tag,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onToggleExpanded,
  });

  final Tag tag;
  final Set<String> selected;
  final Set<String> expanded;
  final Function(Tag, List<Tag>?) onToggle;
  final Function(String) onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = expanded.contains(tag.id);

    // Only watch children if expanded OR we already have some selection logic that needs it.
    // For true lazy loading, we only fetch when expanded.
    if (!tag.hasChildren) {
      return TagChip(
        tag: tag,
        selectionState: selected.contains(tag.id)
            ? SelectionState.all
            : SelectionState.none,
        onToggle: () => onToggle(tag, null),
      );
    }

    // When expanded, we fetch the children
    final subTagsAsync = isExpanded
        ? ref.watch(tagsProvider(parentId: tag.id))
        : const AsyncValue<List<Tag>>.data([]);

    return subTagsAsync.when(
      data: (children) {
        // Selection state logic
        final selectedCount = children
            .where((c) => selected.contains(c.id))
            .length;
        final selectionState = selectedCount == 0
            ? SelectionState.none
            : selectedCount == children.length
            ? SelectionState.all
            : SelectionState.intermediate;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TagChip(
              tag: tag,
              selectionState: selectionState,
              onToggle: () {
                if (tag.hasChildren) {
                  onToggleExpanded(tag.id);
                } else {
                  onToggle(tag, null);
                }
              },
              showExpand: true,
              isExpanded: isExpanded,
              count: selectedCount > 0 ? selectedCount : null,
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: children.map((child) {
                    return TagChip(
                      tag: child,
                      selectionState: selected.contains(child.id)
                          ? SelectionState.all
                          : SelectionState.none,
                      onToggle: () => onToggle(child, null),
                      isSmall: true,
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
      loading: () => TagChip(
        tag: tag,
        selectionState: selected.contains(tag.id)
            ? SelectionState.all
            : SelectionState.none,
        onToggle: () => onToggleExpanded(tag.id),
        showExpand: true,
        isExpanded: isExpanded,
      ),
      error: (e, s) => TagChip(
        tag: tag,
        selectionState: SelectionState.none,
        onToggle: () => onToggleExpanded(tag.id),
      ),
    );
  }
}

enum SelectionState { all, none, intermediate }

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.tag,
    required this.selectionState,
    required this.onToggle,
    this.isSmall = false,
    this.showExpand = false,
    this.isExpanded = false,
    this.count,
  });

  final Tag tag;
  final SelectionState selectionState;
  final VoidCallback onToggle;
  final bool isSmall;
  final bool showExpand;
  final bool isExpanded;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectionState == SelectionState.all;
    final isIntermediate = selectionState == SelectionState.intermediate;

    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appPalette.primary
              : isIntermediate
              ? context.appPalette.primary.withValues(alpha: 0.1)
              : context.appPalette.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: (isSelected || isIntermediate)
                ? context.appPalette.primary
                : context.appPalette.border,
            width: isIntermediate ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.appPalette.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 10 : 16,
                vertical: isSmall ? 6 : 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(context, isSelected || isIntermediate),
                  const SizedBox(width: 8),
                  Text(
                    tag.name + (count != null ? ' ($count)' : ''),
                    style:
                        (isSmall
                                ? context.appTypography.bodySM
                                : context.appTypography.labelMD)
                            .copyWith(
                              color: isSelected
                                  ? context.appPalette.surface
                                  : context.appPalette.primary,
                            ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.check,
                      size: AppIconSizes.xs,
                      color: context.appPalette.surface,
                    ),
                  ],
                  if (showExpand) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.5 : 0,
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: AppIconSizes.m,
                        color: isSelected
                            ? context.appPalette.surface
                            : context.appPalette.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, bool active) {
    if (tag.icon == null || tag.icon!.isEmpty) {
      return Icon(
        LucideIcons.utensils,
        size: isSmall ? 14 : 16,
        color: active ? context.appPalette.surface : context.appPalette.primary,
      );
    }

    if (_isEmoji(tag.icon!)) {
      return Text(
        tag.icon!,
        style:
            (isSmall
                    ? context.appTypography.bodyMD
                    : context.appTypography.bodyLG)
                .copyWith(),
      );
    }

    if (tag.icon!.startsWith('http')) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Opacity(
          opacity: active ? 1.0 : 0.7,
          child: CachedNetworkImage(
            imageUrl: tag.icon!,
            width: isSmall ? 14 : 16,
            height: isSmall ? 14 : 16,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => Icon(
              LucideIcons.utensils,
              size: isSmall ? 14 : 16,
              color: active ? context.appPalette.surface : context.appPalette.primary,
            ),
          ),
        ),
      );
    }

    return Icon(
      _getLucideIcon(tag.icon!),
      size: isSmall ? 14 : 16,
      color: active ? context.appPalette.surface : context.appPalette.primary,
    );
  }

  bool _isEmoji(String text) {
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
    );
    return emojiRegex.hasMatch(text);
  }

  IconData _getLucideIcon(String name) {
    switch (name.toLowerCase()) {
      case 'utensils':
        return LucideIcons.utensils;
      case 'leaf':
        return LucideIcons.leaf;
      case 'apple':
        return LucideIcons.apple;
      case 'coffee':
        return LucideIcons.coffee;
      case 'soup':
        return LucideIcons.soup;
      case 'pizza':
        return LucideIcons.pizza;
      case 'sandwich':
        return LucideIcons.sandwich;
      case 'ice-cream':
        return LucideIcons.iceCream;
      case 'beer':
        return LucideIcons.beer;
      case 'wine':
        return LucideIcons.wine;
      default:
        return LucideIcons.utensils;
    }
  }
}
