import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/socket_events.dart';
import '../models/event.dart';
import '../services/event.dart';
import '../services/location_permission.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/map_provider_type.dart';
import '../services/socket.dart';
import '../services/tag.dart';
import '../services/user.dart';
import '../theme/theme.dart';
import '../utils/event_status.dart';
import '../utils/explore_filters.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/button.dart';
import '../widgets/card.dart';
import '../widgets/explore_event_map.dart';
import '../widgets/explore_search_bar.dart';
import 'event_detail.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  static const String routePath = '/explore';

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with WidgetsBindingObserver {
  static const int _eventPageSize = 100;
  static const List<double> _radiusPresets = <double>[5, 10, 25, 50, 100, 250, 500];
  static const List<_ExploreEventTypeOption> _eventTypeOptions =
      <_ExploreEventTypeOption>[
        _ExploreEventTypeOption(null, 'Any Type'),
        _ExploreEventTypeOption(ExploreEventTypeValues.organized, 'Organized'),
        _ExploreEventTypeOption(ExploreEventTypeValues.custom, 'Custom'),
      ];
  static const List<_ExploreDatePresetOption> _datePresetOptions =
      <_ExploreDatePresetOption>[
        _ExploreDatePresetOption(ExploreDatePresetValues.anytime, 'Anytime'),
        _ExploreDatePresetOption(ExploreDatePresetValues.today, 'Today'),
        _ExploreDatePresetOption(ExploreDatePresetValues.thisWeek, 'This Week'),
        _ExploreDatePresetOption(ExploreDatePresetValues.thisMonth, 'This Month'),
      ];

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  final MapManager _mapManager = MapManager(type: MapProviderType.google);
  final Map<String, _ExploreEventCacheEntry> _eventCacheByFilter =
      <String, _ExploreEventCacheEntry>{};

  bool _showDetails = false;
  bool _isFilterOpen = false;
  bool _isLoading = true;
  bool _isSelectedEventLoading = false;
  bool _isFetchingMoreEvents = false;
  bool _isLocationEnabled = true;
  bool _hasNextEvents = true;
  int _selectedEventRequestVersion = 0;
  String? _nextEventsCursor;

  List<Event> _events = <Event>[];
  List<Tag> _rootTags = <Tag>[];
  Event? _selectedEvent;
  LatLng? _userLocation;
  LatLng? _profileLocation;
  ExploreFilterState _appliedFilters = const ExploreFilterState();
  ExploreFilterState _draftFilters = const ExploreFilterState();

  static const List<_QuickFilter> _quickFilters = <_QuickFilter>[
    _QuickFilter(EventStatusValue.all, 'All', LucideIcons.sparkles),
    _QuickFilter(EventStatusValue.ongoing, 'Ongoing', LucideIcons.timer),
    _QuickFilter(EventStatusValue.upcoming, 'Upcoming', LucideIcons.calendar),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftFilters = _appliedFilters;
    _listenToSocketMessages();
    _initializeExplore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationPermission();
    }
  }

  LatLng? get _effectiveLocation => _userLocation ?? _profileLocation;

  List<Event> get _visibleEvents => _events;

  Event? get _selectedVisibleEvent {
    final selected = _selectedEvent;
    if (selected != null) {
      for (final event in _visibleEvents) {
        if (event.id == selected.id) {
          return event;
        }
      }
    }
    return _visibleEvents.isNotEmpty ? _visibleEvents.first : null;
  }

  bool get _shouldShowLocationNudge =>
      !_isLoading && _effectiveLocation == null;

  bool get _shouldShowRadiusExpansionBanner =>
      !_isLoading &&
      _effectiveLocation != null &&
      _visibleEvents.isEmpty &&
      _appliedFilters.radiusKm < 500;

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
    if (!hasAccess) {
      unawaited(_refreshEventsForCurrentFilters());
    }
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
      unawaited(_refreshEventsForCurrentFilters());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLocation = null;
      });
      unawaited(_refreshEventsForCurrentFilters());
    }
  }

  Future<void> _loadProfileLocation() async {
    try {
      final user = await userService.getCurrentUser();
      final address = user?.address;
      if (!mounted || address?.latitude == null || address?.longitude == null) {
        return;
      }
      setState(() {
        _profileLocation = LatLng(address!.latitude!, address.longitude!);
      });
      unawaited(_refreshEventsForCurrentFilters());
    } catch (_) {
      // Ignore profile location failures on explore.
    }
  }

  Future<void> _loadRootTags() async {
    try {
      final tags = await tagService.getTags(rootOnly: true);
      if (!mounted) return;
      setState(() {
        _rootTags = tags;
      });
    } catch (_) {
      // Filter UI can still function without tags.
    }
  }

  List<Event> _mergeEvents(List<Event> existing, List<Event> incoming) {
    final merged = <String, Event>{
      for (final event in existing) event.id: event,
      for (final event in incoming) event.id: event,
    };
    return merged.values.toList();
  }

  String _buildFilterCacheKey(ExploreFilterState filters, LatLng? location) {
    final sortedTags = filters.tagIds.toList()..sort();
    final locationKey = location == null
        ? 'no-location'
        : '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}';
    return [
      filters.quickStatus,
      filters.radiusKm.round().toString(),
      filters.eventType ?? 'any-type',
      filters.datePreset,
      sortedTags.join(','),
      locationKey,
    ].join('|');
  }

  String? _statusQueryForFilters(ExploreFilterState filters) {
    return switch (filters.quickStatus) {
      EventStatusValue.ongoing => EventStatusValue.ongoing,
      EventStatusValue.upcoming => EventStatusValue.upcoming,
      _ => null,
    };
  }

  bool _eventMatchesActiveFilters(Event event) {
    return matchesExploreFilters(
      event,
      filters: _appliedFilters,
      effectiveLocation: _effectiveLocation,
    );
  }

  void _applyCachedEntry(String cacheKey, _ExploreEventCacheEntry cached) {
    final previousSelectedId = _selectedEvent?.id;
    final nextSelected = previousSelectedId == null
        ? (cached.events.isNotEmpty ? cached.events.first : null)
        : cached.events.where((event) => event.id == previousSelectedId).firstOrNull ??
            (cached.events.isNotEmpty ? cached.events.first : null);

    setState(() {
      _events = cached.events;
      _selectedEvent = nextSelected;
      _showDetails = nextSelected != null && _showDetails;
      _nextEventsCursor = cached.nextCursor;
      _hasNextEvents = cached.hasNext;
      _isLoading = false;
      _isFetchingMoreEvents = false;
    });

    if (_selectedEvent != null) {
      unawaited(
        _hydrateSelectedEvent(_selectedEvent!, _selectedEventRequestVersion),
      );
    }
  }

  Future<void> _refreshEventsForCurrentFilters({bool force = false}) async {
    final location = _effectiveLocation;
    final cacheKey = _buildFilterCacheKey(_appliedFilters, location);
    if (!force) {
      final cached = _eventCacheByFilter[cacheKey];
      if (cached != null) {
        _applyCachedEntry(cacheKey, cached);
        return;
      }
    }
    await _loadEvents(
      refresh: true,
      filters: _appliedFilters,
      effectiveLocation: location,
      cacheKey: cacheKey,
    );
  }

  Future<void> _loadEvents({
    bool refresh = false,
    ExploreFilterState? filters,
    LatLng? effectiveLocation,
    String? cacheKey,
  }) async {
    if (_isFetchingMoreEvents || (!refresh && !_hasNextEvents)) {
      return;
    }

    final resolvedFilters = filters ?? _appliedFilters;
    final resolvedLocation = effectiveLocation ?? _effectiveLocation;
    final resolvedCacheKey =
        cacheKey ?? _buildFilterCacheKey(resolvedFilters, resolvedLocation);

    if (refresh) {
      setState(() {
        _isLoading = true;
        _nextEventsCursor = null;
        _hasNextEvents = true;
      });
    } else {
      setState(() => _isFetchingMoreEvents = true);
    }

    try {
      final result = await eventService.getEvents(
        status: _statusQueryForFilters(resolvedFilters),
        type: resolvedFilters.eventType,
        datePreset: resolvedFilters.datePreset,
        latitude: resolvedLocation?.latitude,
        longitude: resolvedLocation?.longitude,
        radiusKm: resolvedLocation == null ? null : resolvedFilters.radiusKm,
        tagIds: resolvedFilters.tagIds,
        limit: _eventPageSize,
        next: refresh ? null : _nextEventsCursor,
      );
      if (!mounted) return;

      final previousSelectedId = _selectedEvent?.id;
      final events = _mergeEvents(refresh ? const <Event>[] : _events, result.items);
      final nextSelected = previousSelectedId == null
          ? (events.isNotEmpty ? events.first : null)
          : events.where((event) => event.id == previousSelectedId).firstOrNull ??
              (events.isNotEmpty ? events.first : null);

      setState(() {
        _events = events;
        _selectedEvent = nextSelected;
        _showDetails = nextSelected != null && (_showDetails || refresh);
        _nextEventsCursor = result.pagination.next;
        _hasNextEvents = result.pagination.hasNext;
        _isLoading = false;
        _isFetchingMoreEvents = false;
      });

      _eventCacheByFilter[resolvedCacheKey] = _ExploreEventCacheEntry(
        events: List<Event>.from(events),
        nextCursor: result.pagination.next,
        hasNext: result.pagination.hasNext,
      );

      if (_selectedEvent != null) {
        unawaited(
          _hydrateSelectedEvent(_selectedEvent!, _selectedEventRequestVersion),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMoreEvents = false;
        });
      }
    }
  }

  Future<void> _initializeExplore() async {
    unawaited(_refreshLocationPermission());
    unawaited(_loadProfileLocation());
    unawaited(_loadRootTags());
    await _refreshEventsForCurrentFilters(force: true);
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
      final activeCacheKey = _buildFilterCacheKey(_appliedFilters, _effectiveLocation);

      setState(() {
        if (eventName == SocketEvents.eventCreated) {
          final newEvent = Event.fromJson(eventData);
          if (_eventMatchesActiveFilters(newEvent) &&
              !_events.any((e) => e.id == newEvent.id)) {
            _events = [..._events, newEvent];
          }
        } else if (eventName == SocketEvents.eventUpdated) {
          final updatedEvent = Event.fromJson(eventData);
          final index = _events.indexWhere((e) => e.id == updatedEvent.id);
          final matches = _eventMatchesActiveFilters(updatedEvent);
          if (index != -1 && matches) {
            final nextEvents = [..._events];
            nextEvents[index] = nextEvents[index].merge(updatedEvent);
            _events = nextEvents;
            if (_selectedEvent?.id == updatedEvent.id) {
              _selectedEvent = _selectedEvent!.merge(updatedEvent);
            }
          } else if (index != -1 && !matches) {
            _events = _events.where((e) => e.id != updatedEvent.id).toList();
            if (_selectedEvent?.id == updatedEvent.id) {
              _selectedEvent = null;
              _showDetails = false;
            }
          } else if (matches) {
            _events = [..._events, updatedEvent];
          }
        } else if (eventName == SocketEvents.eventDeleted) {
          final eventId = eventData['id'];
          _events = _events.where((e) => e.id != eventId).toList();
          if (_selectedEvent?.id == eventId) {
            _selectedEvent = null;
            _showDetails = false;
          }
        }

        _eventCacheByFilter[activeCacheKey] = _ExploreEventCacheEntry(
          events: List<Event>.from(_events),
          nextCursor: _nextEventsCursor,
          hasNext: _hasNextEvents,
        );
      });
    });
  }

  void _openFilters() {
    setState(() {
      _draftFilters = _appliedFilters.copyWith(
        tagIds: {..._appliedFilters.tagIds},
      );
      _isFilterOpen = true;
    });
  }

  void _applyQuickFilter(String quickStatus) {
    setState(() {
      _appliedFilters = _appliedFilters.copyWith(quickStatus: quickStatus);
    });
    unawaited(_refreshEventsForCurrentFilters());
  }

  void _toggleDraftTag(String tagId) {
    final next = {..._draftFilters.tagIds};
    if (next.contains(tagId)) {
      next.remove(tagId);
    } else {
      next.add(tagId);
    }

    setState(() {
      _draftFilters = _draftFilters.copyWith(tagIds: next);
    });
  }

  void _applyDrawerFilters() {
    setState(() {
      _appliedFilters = _draftFilters.copyWith(
        tagIds: {..._draftFilters.tagIds},
      );
      _isFilterOpen = false;
    });
    unawaited(_refreshEventsForCurrentFilters());
  }

  void _resetDrawerFilters() {
    setState(() {
      _draftFilters = ExploreFilterState(
        quickStatus: _appliedFilters.quickStatus,
      );
    });
  }

  void _expandRadius() {
    final current = _appliedFilters.radiusKm;
    final nextRadius = _radiusPresets.firstWhere(
      (radius) => radius > current,
      orElse: () => current,
    );
    if (nextRadius == current) return;

    setState(() {
      _appliedFilters = _appliedFilters.copyWith(radiusKm: nextRadius);
      _draftFilters = _draftFilters.copyWith(radiusKm: nextRadius);
    });
    unawaited(_refreshEventsForCurrentFilters());
  }

  Future<void> _requestCurrentLocationFromNudge() async {
    final status = await LocationPermissionService.requestOnStartup();
    if (!LocationPermissionService.hasAccess(status)) {
      if (!mounted) return;
      setState(() {
        _isLocationEnabled = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLocationEnabled = true;
    });
    await _loadCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    final selectedVisibleEvent = _selectedVisibleEvent;
    final resolvedSelectedEvent = selectedVisibleEvent ?? _selectedEvent;
    final resolvedStatus = resolvedSelectedEvent != null
        ? resolveEventStatus(resolvedSelectedEvent)
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: ExploreEventMap(
              manager: _mapManager,
              events: _visibleEvents,
              selectedEvent: selectedVisibleEvent,
              userLocation: _effectiveLocation,
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
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExploreSearchBar(onOpenFilters: _openFilters),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _quickFilters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final filter = _quickFilters[index];
                          final isSelected =
                              _appliedFilters.quickStatus == filter.id;
                          return GestureDetector(
                            onTap: () => _applyQuickFilter(filter.id),
                            child: _buildQuickFilterChip(filter, isSelected),
                          );
                        },
                      ),
                    ),
                    if (_shouldShowLocationNudge) ...[
                      const SizedBox(height: 10),
                      _buildInfoBanner(
                        icon: LucideIcons.locateFixed,
                        message:
                            'Add your current location to see nearby events around you.',
                        ctaLabel: 'Use current location',
                        onTap: _requestCurrentLocationFromNudge,
                      ),
                    ] else if (_shouldShowRadiusExpansionBanner) ...[
                      const SizedBox(height: 10),
                      _buildInfoBanner(
                        icon: LucideIcons.search,
                        message:
                            'No events found within ${_appliedFilters.radiusKm.toStringAsFixed(0)} km. Expand the radius to discover more nearby events.',
                        ctaLabel: 'Expand radius',
                        onTap: _expandRadius,
                      ),
                    ] else if (!_isLocationEnabled) ...[
                      const SizedBox(height: 10),
                      _buildInfoBanner(
                        icon: LucideIcons.alertTriangle,
                        message:
                            'Location is disabled. Nearby results may be incomplete.',
                        ctaLabel: 'Enable location',
                        onTap: _requestCurrentLocationFromNudge,
                      ),
                    ],
                    if (_isFetchingMoreEvents) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          if (_showDetails && resolvedSelectedEvent != null)
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl:
                                resolvedSelectedEvent.media?.firstOrNull?.url ??
                                'https://picsum.photos/seed/${resolvedSelectedEvent.id}/200/200',
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
                                      resolvedSelectedEvent.name,
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
                                      color: _statusColor(resolvedStatus!),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${formatEventStatusLabel(resolvedStatus).toUpperCase()} · Free Entry',
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
                                      _getRelativeTime(
                                        resolvedSelectedEvent.startTime,
                                        resolvedSelectedEvent.endTime,
                                      ),
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
                    if (resolvedSelectedEvent.tags?.isNotEmpty == true)
                      SizedBox(
                        height: 28,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemCount: resolvedSelectedEvent.tags!.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, index) => _tag(
                            resolvedSelectedEvent.tags![index].name
                                .toUpperCase(),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        _engagementMeta(
                          LucideIcons.eye,
                          '${resolvedSelectedEvent.stats?.viewCount ?? 0} views',
                        ),
                        Flexible(
                          child: _engagementMeta(
                            LucideIcons.star,
                            resolvedSelectedEvent.stats != null &&
                                    resolvedSelectedEvent.stats!.ratingCount > 0
                                ? '${resolvedSelectedEvent.stats!.ratingAverage.toStringAsFixed(1)} (${resolvedSelectedEvent.stats!.ratingCount})'
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
                                resolvedSelectedEvent.id,
                              ),
                              extra: resolvedSelectedEvent,
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

          const AppBottomNav(),
          if (_isFilterOpen) _buildFilterDrawer(),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(_QuickFilter filter, bool isSelected) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            filter.icon,
            size: AppIconSizes.m,
            color: isSelected ? AppColors.surface : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            filter.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.surface : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String message,
    String? ctaLabel,
    VoidCallback? onTap,
  }) {
    final hasAction = ctaLabel != null && onTap != null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: AppIconSizes.m, color: AppColors.warning),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  height: 1.35,
                ),
                children: [
                  TextSpan(text: message),
                  if (hasAction) const TextSpan(text: ' '),
                  if (hasAction)
                    TextSpan(
                      text: ctaLabel,
                      recognizer: TapGestureRecognizer()..onTap = onTap,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.7),
            ),
          ),
          child: content,
        ),
      ),
    );
  }

  String _getRelativeTime(DateTime startTime, DateTime endTime) {
    final now = DateTime.now();
    final status = deriveEventStatus(startTime: startTime, endTime: endTime);

    if (status == EventStatusValue.completed) {
      return 'Ended';
    }

    if (status == EventStatusValue.upcoming) {
      final diff = startTime.difference(now);
      if (diff.inHours > 0) {
        return 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      }
      return 'Starts in ${diff.inMinutes} mins';
    }

    final diff = endTime.difference(now);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    }
    return '${diff.inMinutes} mins remaining';
  }

  Color _statusColor(String status) {
    switch (status) {
      case EventStatusValue.ongoing:
        return AppColors.success;
      case EventStatusValue.upcoming:
        return AppColors.warning;
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
      default:
        return AppColors.mutedForeground;
    }
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
        GestureDetector(
          onTap: () => setState(() => _isFilterOpen = false),
          child: Container(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.78,
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
                        Text(
                          '${_draftFilters.radiusKm.toStringAsFixed(0)} km',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Slider(
                          value: _draftFilters.radiusKm.clamp(1, 500),
                          min: 1,
                          max: 500,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.muted,
                          onChanged: (value) {
                            setState(() {
                              _draftFilters = _draftFilters.copyWith(
                                radiusKm: value.roundToDouble(),
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('EVENT TYPE'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _eventTypeOptions.map((option) {
                            final selected = _draftFilters.eventType == option.value ||
                                (_draftFilters.eventType == null &&
                                    option.value == null);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _draftFilters = _draftFilters.copyWith(
                                    eventType: option.value,
                                  );
                                });
                              },
                              child: _chipButton(
                                option.label,
                                selected: selected,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('TIME'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _datePresetOptions.map((option) {
                            final selected =
                                _draftFilters.datePreset == option.value;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _draftFilters = _draftFilters.copyWith(
                                    datePreset: option.value,
                                  );
                                });
                              },
                              child: _chipButton(
                                option.label,
                                selected: selected,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('CATEGORIES'),
                        const SizedBox(height: 12),
                        if (_rootTags.isEmpty)
                          const Text(
                            'Categories are unavailable right now.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _rootTags.map((tag) {
                              final selected = _draftFilters.tagIds.contains(
                                tag.id,
                              );
                              return GestureDetector(
                                onTap: () => _toggleDraftTag(tag.id),
                                child: _chipButton(
                                  tag.name,
                                  selected: selected,
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
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
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.lg,
                          label: 'Reset',
                          onPressed: _resetDrawerFilters,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          size: AppButtonSize.lg,
                          label: 'Apply Filters',
                          onPressed: _applyDrawerFilters,
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

  @override
  void dispose() {
    _socketSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _QuickFilter {
  const _QuickFilter(this.id, this.name, this.icon);

  final String id;
  final String name;
  final IconData icon;
}

class _ExploreEventTypeOption {
  const _ExploreEventTypeOption(this.value, this.label);

  final String? value;
  final String label;
}

class _ExploreDatePresetOption {
  const _ExploreDatePresetOption(this.value, this.label);

  final String value;
  final String label;
}

class _ExploreEventCacheEntry {
  const _ExploreEventCacheEntry({
    required this.events,
    required this.nextCursor,
    required this.hasNext,
  });

  final List<Event> events;
  final String? nextCursor;
  final bool hasNext;
}
