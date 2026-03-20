import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/explore_event_map.dart';
import '../widgets/explore_search_bar.dart';
import '../services/event.dart';
import '../models/event.dart';
import '../services/socket.dart';
import '../services/location_permission.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/map_provider_type.dart';
import '../constants/socket_events.dart';
import 'event_detail.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  static const String routePath = '/explore';

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  bool _showDetails = false;
  bool _isFilterOpen = false;
  List<Event> _events = [];
  Event? _selectedEvent;
  bool _isLoading = true;
  bool _isSelectedEventLoading = false;
  bool _isLocationEnabled = true;
  LatLng? _userLocation;
  final MapManager _mapManager = MapManager(type: MapProviderType.google);
  int _selectedEventRequestVersion = 0;

  final _filters = [
    _Filter('ongoing', 'Ongoing Now', LucideIcons.timer),
    _Filter('vegan', 'Vegan', null),
    _Filter('street', 'Street Food', null),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationPermission();
    _loadEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationPermission();
    }
  }

  Future<void> _refreshLocationPermission() async {
    final status = await LocationPermissionService.currentStatus();
    final hasAccess = LocationPermissionService.hasAccess(status);
    if (hasAccess) {
      await _loadCurrentLocation();
    }
    if (!mounted) return;
    setState(() {
      _isLocationEnabled = hasAccess;
      if (!hasAccess) {
        _userLocation = null;
      }
    });
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLocation = null;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final result = await eventService.getEvents(limit: 50);
      if (mounted) {
        setState(() {
          _events = result.items;
          if (_events.isNotEmpty && _selectedEvent == null) {
            _selectedEvent = _events.first;
            _showDetails = true;
          }
          _isLoading = false;
        });
        if (_selectedEvent != null) {
          unawaited(
            _hydrateSelectedEvent(
              _selectedEvent!,
              _selectedEventRequestVersion,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
    _listenToSocketMessages();
  }

  Future<void> _hydrateSelectedEvent(Event event, int requestVersion) async {
    if (!mounted) return;
    setState(() => _isSelectedEventLoading = true);

    try {
      final preview = await eventService.getEventPreview(event.id);
      if (!mounted || requestVersion != _selectedEventRequestVersion) return;

      final merged = event.merge(preview);
      setState(() {
        _selectedEvent = merged;
        _isSelectedEventLoading = false;
      });
    } catch (_) {
      if (!mounted || requestVersion != _selectedEventRequestVersion) return;
      setState(() => _isSelectedEventLoading = false);
    }
  }

  void _selectEvent(Event event) {
    final requestVersion = ++_selectedEventRequestVersion;

    setState(() {
      _selectedEvent = event;
      _showDetails = true;
      _isSelectedEventLoading = false;
    });

    if (!event.hasPreviewData) {
      _hydrateSelectedEvent(event, requestVersion);
    }
  }

  void _listenToSocketMessages() {
    _socketSubscription?.cancel();
    _socketSubscription = socketService.messages.listen((event) {
      if (!mounted) return;

      final eventName = event['event'];
      final eventData = event['data'];

      setState(() {
        if (eventName == SocketEvents.eventCreated) {
          final newEvent = Event.fromJson(eventData);
          if (!_events.any((e) => e.id == newEvent.id)) {
            _events.add(newEvent);
          }
        } else if (eventName == SocketEvents.eventUpdated) {
          final updatedEvent = Event.fromJson(eventData);
          final index = _events.indexWhere((e) => e.id == updatedEvent.id);
          if (index != -1) {
            _events[index] = _events[index].merge(updatedEvent);
            if (_selectedEvent?.id == updatedEvent.id) {
              _selectedEvent = _selectedEvent!.merge(updatedEvent);
            }
          }
        } else if (eventName == SocketEvents.eventDeleted) {
          final eventId = eventData['id'];
          _events.removeWhere((e) => e.id == eventId);
          if (_selectedEvent?.id == eventId) {
            _selectedEvent = null;
            _showDetails = false;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: ExploreEventMap(
              manager: _mapManager,
              events: _events,
              selectedEvent: _selectedEvent,
              userLocation: _userLocation,
              onEventSelected: _selectEvent,
              onClusterFocusStart: () {
                setState(() {
                  _showDetails = false;
                });
              },
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            ...[],

          // Search bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    ExploreSearchBar(
                      onOpenFilters: () => setState(() => _isFilterOpen = true),
                    ),
                    const SizedBox(height: 12),

                    // Filter chips
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final f = _filters[i];
                          final isFirst = i == 0;
                          return Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isFirst
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: isFirst
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              boxShadow: isFirst
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (f.icon != null) ...[
                                  Icon(
                                    f.icon,
                                    size: AppIconSizes.m,
                                    color: isFirst
                                        ? AppColors.surface
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  f.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isFirst
                                        ? AppColors.surface
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (!_isLocationEnabled) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              LucideIcons.alertTriangle,
                              size: AppIconSizes.m,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location is disabled. Nearby results may be incomplete.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Event card (bottom sheet)
          if (_showDetails && _selectedEvent != null)
            Positioned(
              bottom: 112,
              left: 20,
              right: 20,
              child: AppCard(
                padding: AppCardPadding.sm,
                child: Column(
                  spacing: 12,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl:
                                _selectedEvent!.media?.firstOrNull?.url ??
                                'https://picsum.photos/seed/${_selectedEvent!.id}/200/200',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedEvent!.name,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _showDetails = false),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: AppColors.muted,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.x,
                                        size: AppIconSizes.m,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _selectedEvent!.status == 'active'
                                          ? AppColors.primary
                                          : AppColors.mutedForeground,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_selectedEvent!.status.toUpperCase()} · Free Entry',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.timer,
                                    size: AppIconSizes.m,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _getRelativeTime(_selectedEvent!.endTime),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tags
                    if (_selectedEvent!.tags?.isNotEmpty == true)
                      SizedBox(
                        height: 28,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedEvent!.tags!.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) =>
                              _tag(_selectedEvent!.tags![i].name.toUpperCase()),
                        ),
                      ),
                    Row(
                      children: [
                        _engagementMeta(
                          LucideIcons.eye,
                          '${_selectedEvent!.stats?.viewCount ?? 0} views',
                        ),
                        Flexible(
                          child: _engagementMeta(
                            LucideIcons.star,
                            _selectedEvent!.stats != null &&
                                    _selectedEvent!.stats!.ratingCount > 0
                                ? '${_selectedEvent!.stats!.ratingAverage.toStringAsFixed(1)} (${_selectedEvent!.stats!.ratingCount})'
                                : 'No ratings',
                          ),
                        ),
                        if (_isSelectedEventLoading)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            size: AppButtonSize.lg,
                            icon: const Icon(LucideIcons.navigation),
                            label: 'Get Directions',
                            onPressed: () => context.go(
                              EventDetailScreen.routePath.replaceAll(
                                ':id',
                                _selectedEvent!.id.toString(),
                              ),
                              extra: _selectedEvent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const AppButton(
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.lg,
                          child: Icon(
                            LucideIcons.share2,
                            size: AppIconSizes.defaultSize,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Bottom nav
          const AppBottomNav(),

          // Filter drawer
          if (_isFilterOpen) _buildFilterDrawer(),
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime endTime) {
    final diff = endTime.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    }
    return '${diff.inMinutes} mins remaining';
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _engagementMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Icon(icon, size: AppIconSizes.s, color: AppColors.mutedForeground),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDrawer() {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: () => setState(() => _isFilterOpen = false),
          child: Container(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        // Drawer
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isFilterOpen = false),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: AppIconSizes.m,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('DISTANCE'),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '5 km',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: 5,
                          min: 1,
                          max: 20,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.muted,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 32),
                        _sectionLabel('CATEGORIES'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                    'Street Food',
                                    'Bakery',
                                    'Vegan',
                                    'Desserts',
                                    'Beverages',
                                  ]
                                  .map(
                                    (c) =>
                                        _chipButton(c, selected: c == 'Bakery'),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 32),
                        _sectionLabel('DIETARY NEEDS'),
                        const SizedBox(height: 12),
                        ...[
                          ('Vegetarian Only', LucideIcons.leaf),
                          ('Gluten-Free', LucideIcons.wheat),
                          ('Halal', LucideIcons.utensilsCrossed),
                        ].map(
                          (d) => _dietaryItem(
                            d.$1,
                            d.$2,
                            selected: d.$1 == 'Halal',
                          ),
                        ),
                        const SizedBox(height: 32),
                        _sectionLabel('TIMING'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _timingCard(
                                'Ongoing Now',
                                LucideIcons.clock,
                                true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _timingCard(
                                'Upcoming',
                                LucideIcons.calendar,
                                false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    border: const Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.lg,
                          label: 'Reset',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          size: AppButtonSize.lg,
                          label: 'Apply Filters',
                          onPressed: () =>
                              setState(() => _isFilterOpen = false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.mutedForeground,
      ),
    );
  }

  Widget _chipButton(String text, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.surface : AppColors.primary,
        ),
      ),
    );
  }

  Widget _dietaryItem(String name, IconData icon, {bool selected = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppIconSizes.m,
              color: selected ? AppColors.surface : AppColors.mutedForeground,
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(
                    LucideIcons.x,
                    size: AppIconSizes.xs,
                    color: AppColors.surface,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _timingCard(String label, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        spacing: 12,
        children: [
          Icon(
            icon,
            size: AppIconSizes.l,
            color: selected ? AppColors.surface : AppColors.mutedForeground,
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: selected ? AppColors.surface : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _Filter {
  _Filter(this.id, this.name, this.icon);

  final String id;
  final String name;
  final IconData? icon;
}
