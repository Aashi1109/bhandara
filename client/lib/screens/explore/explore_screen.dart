import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../constants/socket_events.dart';
import '../../models/event.dart';
import '../../services/event.dart';
import '../../services/location_permission.dart';
import '../../services/maps/map_manager.dart';
import '../../services/maps/map_provider_type.dart';
import '../../services/socket.dart';
import '../../services/tag.dart';
import '../../services/user.dart';
import '../../theme/theme.dart';
import '../../utils/event_status.dart';
import 'models/event_cluster.dart';
import 'models/event_marker.dart';
import 'utils/explore_event_cards.dart';
import 'utils/explore_filters.dart';
import 'utils/explore_viewport.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/button.dart';
import '../../widgets/card.dart';
import '../../widgets/event_status_badge.dart';
import '../../widgets/skeleton.dart';
import 'widgets/explore_event_map.dart';
import 'widgets/explore_search_bar.dart';
import '../event_detail.dart';
import '../search.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  static const String routePath = '/explore';

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with WidgetsBindingObserver {
  static const bool _useSimpleMarkerFetch = false;
  static const int _eventPageSize = 100;
  static const List<double> _radiusPresets = <double>[
    5,
    10,
    25,
    50,
    100,
    250,
    500,
  ];
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
        _ExploreDatePresetOption(
          ExploreDatePresetValues.thisMonth,
          'This Month',
        ),
      ];

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  final MapManager _mapManager = MapManager(type: MapProviderType.google);
  final Map<String, _ExploreEventCacheEntry> _eventCacheByFilter =
      <String, _ExploreEventCacheEntry>{};
  final Map<String, List<EventMarker>> _markerCacheByFilter =
      <String, List<EventMarker>>{};
  final GlobalKey _topOverlayKey = GlobalKey();
  final GlobalKey _detailsCardKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();
  late final PageController _detailsPageController;

  bool _showDetails = false;
  bool _isFilterOpen = false;
  bool _isLoading = true;
  bool _isSelectedEventLoading = false;
  bool _isFetchingMoreEvents = false;
  bool _isLocationEnabled = true;
  bool _hasNextEvents = true;
  bool _viewportPaddingMeasurementScheduled = false;
  bool? _lastMeasuredShowDetails;
  bool? _lastMeasuredFilterOpen;
  int _selectedEventRequestVersion = 0;
  int _selectedEventFocusRequestId = 0;
  int _selectedEventPageIndex = 0;
  String? _nextEventsCursor;

  List<Event> _events = <Event>[];
  List<Tag> _rootTags = <Tag>[];
  Event? _selectedEvent;
  LatLng? _userLocation;
  LatLng? _profileLocation;
  EdgeInsets _mapSafeAreaPadding = const EdgeInsets.fromLTRB(20, 160, 84, 140);
  ExploreFilterState _appliedFilters = const ExploreFilterState();
  ExploreFilterState _draftFilters = const ExploreFilterState();
  ExploreMapQueryMode _queryMode = ExploreMapQueryMode.followLocation;
  ExploreViewportQuery? _viewportQuery;

  // Marker tile cache state
  Map<String, List<EventMarker>> _tileCache = {};
  List<EventMarker> _visibleMarkers = [];
  List<EventCluster> _serverClusters = [];
  final Map<String, Event> _markerPreviewCache = {};
  bool _isClusterMode = true;
  int _markerRequestVersion = 0;

  /// The viewport that was actually sent to the server for the last
  /// successful cluster fetch (center + the over-fetched radius).
  /// Used to skip refetches when the user pans within the already-covered area.
  LatLng? _lastClusterFetchCenter;
  double _lastClusterFetchRadius = 0;
  int _lastClusterFetchZoom = 0;

  static const List<_QuickFilter> _quickFilters = <_QuickFilter>[
    _QuickFilter(EventStatusValue.all, 'All', LucideIcons.sparkles),
    _QuickFilter(EventStatusValue.ongoing, 'Ongoing', LucideIcons.timer),
    _QuickFilter(EventStatusValue.upcoming, 'Upcoming', LucideIcons.calendar),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detailsPageController = PageController();
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

  bool get _isViewportMode => _queryMode == ExploreMapQueryMode.viewport;

  LatLng? get _activeFetchLocation =>
      _isViewportMode ? _viewportQuery?.center : _effectiveLocation;

  double? get _activeRadiusKm {
    final location = _activeFetchLocation;
    if (location == null) {
      return null;
    }

    return _isViewportMode
        ? _viewportQuery?.radiusKm
        : _appliedFilters.radiusKm;
  }

  List<Event> get _visibleEvents => _events;

  int get _selectedVisibleEventIndex =>
      findExploreEventIndex(_visibleEvents, _selectedEvent?.id);

  Event? get _selectedVisibleEvent {
    return reconcileSelectedExploreEvent(_visibleEvents, _selectedEvent);
  }

  bool get _shouldShowLocationNudge =>
      !_isLoading && !_isViewportMode && _effectiveLocation == null;

  bool get _shouldShowRadiusExpansionBanner =>
      !_isLoading &&
      !_isViewportMode &&
      _effectiveLocation != null &&
      _visibleEvents.isEmpty &&
      _appliedFilters.radiusKm < 500;

  ExploreFilterState get _activeFilterState {
    if (!_isViewportMode || _viewportQuery == null) {
      return _appliedFilters;
    }

    return _appliedFilters.copyWith(radiusKm: _viewportQuery!.radiusKm);
  }

  void _scheduleMapPaddingMeasurement() {
    if (_viewportPaddingMeasurementScheduled) {
      return;
    }

    _viewportPaddingMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportPaddingMeasurementScheduled = false;
      if (!mounted) return;

      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final topRect = _globalRectFor(_topOverlayKey);
      final detailsRect = _globalRectFor(_detailsCardKey);
      final navRect = _globalRectFor(_bottomNavKey);

      final topPadding = topRect?.bottom ?? _mapSafeAreaPadding.top;
      final bottomOverlayTop =
          <double>[
            if (detailsRect != null) detailsRect.top,
            if (navRect != null) navRect.top,
          ].fold<double>(
            screenHeight,
            (current, top) => top < current ? top : current,
          );
      final bottomPadding = bottomOverlayTop == screenHeight
          ? _mapSafeAreaPadding.bottom
          : screenHeight - bottomOverlayTop;
      final nextPadding = EdgeInsets.fromLTRB(
        20,
        topPadding,
        84,
        bottomPadding,
      );

      if (_edgeInsetsChanged(_mapSafeAreaPadding, nextPadding)) {
        setState(() {
          _mapSafeAreaPadding = nextPadding;
        });
      }
    });
  }

  Rect? _globalRectFor(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  bool _edgeInsetsChanged(EdgeInsets current, EdgeInsets next) {
    const tolerance = 0.5;
    return (current.left - next.left).abs() > tolerance ||
        (current.top - next.top).abs() > tolerance ||
        (current.right - next.right).abs() > tolerance ||
        (current.bottom - next.bottom).abs() > tolerance;
  }

  Future<void> _refreshLocationPermission() async {
    await _resolveUserLocation();
    if (!mounted) return;
    if (!_isViewportMode) {
      unawaited(_refreshEventsForCurrentFilters());
      _refreshMarkersForCurrentState();
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

  List<EventMarker> _normalizeMarkers(Iterable<EventMarker> markers) {
    final normalizedMarkers = <EventMarker>[];
    final seenIds = <String>{};

    for (final marker in markers) {
      if (marker.id.isEmpty || !seenIds.add(marker.id)) {
        continue;
      }

      normalizedMarkers.add(marker);
    }

    return normalizedMarkers;
  }

  void _cacheMarkerPreviewEvents(Iterable<Event> events) {
    _markerPreviewCache
      ..clear()
      ..addEntries(
        events
            .where(
              (event) =>
                  event.id.isNotEmpty &&
                  event.location.latitude != null &&
                  event.location.longitude != null,
            )
            .map((event) => MapEntry(event.id, event)),
      );
  }

  void _applyFlatMarkerCacheEntry(String cacheKey, List<EventMarker> markers) {
    final normalizedMarkers = _normalizeMarkers(markers);
    _markerCacheByFilter[cacheKey] = List<EventMarker>.from(normalizedMarkers);

    setState(() {
      _isClusterMode = false;
      _visibleMarkers = normalizedMarkers;
      _serverClusters = [];
      _tileCache = {};
      _lastClusterFetchCenter = null;
      _lastClusterFetchRadius = 0;
      _lastClusterFetchZoom = 0;
    });
  }

  Future<void> _refreshFlatMarkersForCurrentFilters({
    bool force = false,
    bool includeLocationFilter = true,
  }) async {
    if (!_useSimpleMarkerFetch) {
      return;
    }

    final location = includeLocationFilter ? _activeFetchLocation : null;
    final radiusKm = includeLocationFilter ? _activeRadiusKm : null;
    final cacheKey = _buildFilterCacheKey(
      _appliedFilters,
      location,
      mode: _queryMode,
      radiusKm: radiusKm,
      viewport: _viewportQuery,
    );

    if (!force) {
      final cached = _markerCacheByFilter[cacheKey];
      if (cached != null) {
        _applyFlatMarkerCacheEntry(cacheKey, cached);
        return;
      }
    }

    try {
      final markers = await _fetchFlatMarkersForFilters(
        filters: _appliedFilters,
        effectiveLocation: location,
        radiusKm: radiusKm,
      );
      if (!mounted) return;
      _applyFlatMarkerCacheEntry(cacheKey, markers);
    } catch (_) {
      // Keep the current marker state if the temporary flat-marker fetch fails.
    }
  }

  Future<List<EventMarker>> _fetchFlatMarkersForFilters({
    required ExploreFilterState filters,
    required LatLng? effectiveLocation,
    required double? radiusKm,
  }) async {
    final markers = await eventService.getFlatEventMarkers(
      status: _statusQueryForFilters(filters),
      type: filters.eventType,
      datePreset: filters.datePreset,
      latitude: effectiveLocation?.latitude,
      longitude: effectiveLocation?.longitude,
      radiusKm: effectiveLocation == null ? null : radiusKm,
      tagIds: filters.tagIds,
    );
    return _normalizeMarkers(markers);
  }

  void _syncDetailsPageToSelection({bool animate = false}) {
    final selectedIndex = _selectedVisibleEventIndex;
    if (selectedIndex == -1) {
      return;
    }

    _selectedEventPageIndex = selectedIndex;

    if (!_detailsPageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _syncDetailsPageToSelection(animate: false);
      });
      return;
    }

    if (!_detailsPageController.position.hasViewportDimension) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _syncDetailsPageToSelection(animate: animate);
      });
      return;
    }

    final currentPage =
        _detailsPageController.page?.round() ??
        _detailsPageController.initialPage;
    if (currentPage == selectedIndex) {
      return;
    }

    if (animate) {
      unawaited(
        _detailsPageController.animateToPage(
          selectedIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }

    _detailsPageController.jumpToPage(selectedIndex);
  }

  void _handleDetailsPageChanged(int index) {
    if (index < 0 || index >= _visibleEvents.length) {
      return;
    }

    final event = _visibleEvents[index];
    if (_selectedEvent?.id == event.id) {
      setState(() {
        _selectedEventPageIndex = index;
      });
      return;
    }

    _selectEvent(event, syncPage: false, animatePage: false);
  }

  String _buildFilterCacheKey(
    ExploreFilterState filters,
    LatLng? location, {
    required ExploreMapQueryMode mode,
    required double? radiusKm,
    ExploreViewportQuery? viewport,
  }) {
    final sortedTags = filters.tagIds.toList()..sort();
    return [
      filters.quickStatus,
      (radiusKm ?? filters.radiusKm).toStringAsFixed(1),
      filters.eventType ?? 'any-type',
      filters.datePreset,
      sortedTags.join(','),
      buildExploreCacheLocationKey(
        mode: mode,
        followLocation: location,
        followRadiusKm: radiusKm,
        viewport: viewport,
      ),
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
      filters: _activeFilterState,
      effectiveLocation: _activeFetchLocation,
    );
  }

  void _applyCachedEntry(String cacheKey, _ExploreEventCacheEntry cached) {
    final cachedMarkers = _useSimpleMarkerFetch
        ? _markerCacheByFilter[cacheKey]
        : null;
    final nextSelected = reconcileSelectedExploreEvent(
      cached.events,
      _selectedEvent,
    );
    final nextSelectedIndex = findExploreEventIndex(
      cached.events,
      nextSelected?.id,
    );
    _cacheMarkerPreviewEvents(cached.events);

    setState(() {
      _events = cached.events;
      _selectedEvent = nextSelected;
      _showDetails = nextSelected != null && _showDetails;
      _selectedEventPageIndex = nextSelectedIndex == -1 ? 0 : nextSelectedIndex;
      _nextEventsCursor = cached.nextCursor;
      _hasNextEvents = cached.hasNext;
      _isLoading = false;
      _isFetchingMoreEvents = false;
      if (_useSimpleMarkerFetch && cachedMarkers != null) {
        _isClusterMode = false;
        _visibleMarkers = cachedMarkers;
        _serverClusters = [];
        _tileCache = {};
        _lastClusterFetchCenter = null;
        _lastClusterFetchRadius = 0;
        _lastClusterFetchZoom = 0;
      }
    });

    if (_selectedEvent != null) {
      _syncDetailsPageToSelection();
      unawaited(
        _hydrateSelectedEvent(_selectedEvent!, _selectedEventRequestVersion),
      );
    }
  }

  Future<void> _refreshEventsForCurrentFilters({bool force = false}) async {
    final location = _activeFetchLocation;
    final radiusKm = _activeRadiusKm;
    final cacheKey = _buildFilterCacheKey(
      _appliedFilters,
      location,
      mode: _queryMode,
      radiusKm: radiusKm,
      viewport: _viewportQuery,
    );
    if (!force) {
      final cached = _eventCacheByFilter[cacheKey];
      if (cached != null) {
        _applyCachedEntry(cacheKey, cached);
        if (_useSimpleMarkerFetch &&
            !_markerCacheByFilter.containsKey(cacheKey)) {
          unawaited(_refreshFlatMarkersForCurrentFilters());
        }
        return;
      }
    }
    await _loadEvents(
      refresh: true,
      filters: _appliedFilters,
      effectiveLocation: location,
      radiusKm: radiusKm,
      mode: _queryMode,
      viewport: _viewportQuery,
      cacheKey: cacheKey,
    );
  }

  Future<void> _loadEvents({
    bool refresh = false,
    ExploreFilterState? filters,
    LatLng? effectiveLocation,
    double? radiusKm,
    ExploreMapQueryMode? mode,
    ExploreViewportQuery? viewport,
    String? cacheKey,
  }) async {
    if (_isFetchingMoreEvents || (!refresh && !_hasNextEvents)) {
      return;
    }

    final resolvedFilters = filters ?? _appliedFilters;
    final resolvedMode = mode ?? _queryMode;
    final resolvedLocation = effectiveLocation ?? _activeFetchLocation;
    final resolvedRadiusKm = radiusKm ?? _activeRadiusKm;
    final resolvedViewport = viewport ?? _viewportQuery;
    final resolvedCacheKey =
        cacheKey ??
        _buildFilterCacheKey(
          resolvedFilters,
          resolvedLocation,
          mode: resolvedMode,
          radiusKm: resolvedRadiusKm,
          viewport: resolvedViewport,
        );

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
        radiusKm: resolvedLocation == null ? null : resolvedRadiusKm,
        tagIds: resolvedFilters.tagIds,
        limit: _eventPageSize,
        next: refresh ? null : _nextEventsCursor,
      );
      if (!mounted) return;

      final events = _mergeEvents(
        refresh ? const <Event>[] : _events,
        result.items,
      );
      final nextSelected = reconcileSelectedExploreEvent(
        events,
        _selectedEvent,
      );
      final nextSelectedIndex = findExploreEventIndex(events, nextSelected?.id);

      setState(() {
        _events = events;
        _selectedEvent = nextSelected;
        _showDetails = nextSelected != null && _showDetails;
        _selectedEventPageIndex = nextSelectedIndex == -1
            ? 0
            : nextSelectedIndex;
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
        _syncDetailsPageToSelection();
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
    unawaited(_loadRootTags());

    // Resolve location and profile location concurrently.
    // Map renders immediately while GPS/profile resolve in the background.
    try {
      await Future.wait([_resolveUserLocation(), _loadProfileLocation()]);
    } catch (e) {
      debugPrint('Explore location resolution error: $e');
    }

    if (!mounted) return;

    // Now that location is known, load events and clusters.
    try {
      await Future.wait([
        _refreshEventsForCurrentFilters(force: true),
        Future<void>.value(),
      ]);
      _refreshMarkersForCurrentState();
    } catch (e) {
      debugPrint('Explore initial load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveUserLocation() async {
    try {
      final status = await LocationPermissionService.currentStatus();
      final hasAccess = LocationPermissionService.hasAccess(status);
      if (!mounted) return;

      setState(() => _isLocationEnabled = hasAccess);

      if (!hasAccess) {
        setState(() => _userLocation = null);
        return;
      }

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
      setState(() => _userLocation = null);
    }
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

  void _selectEvent(
    Event event, {
    bool syncPage = true,
    bool animatePage = true,
  }) {
    final requestVersion = ++_selectedEventRequestVersion;
    final selectedIndex = findExploreEventIndex(_visibleEvents, event.id);

    setState(() {
      _selectedEvent = event;
      _showDetails = true;
      _isSelectedEventLoading = false;
      _selectedEventPageIndex = selectedIndex == -1 ? 0 : selectedIndex;
      _selectedEventFocusRequestId++;
    });

    if (syncPage && selectedIndex != -1) {
      _syncDetailsPageToSelection(animate: animatePage);
    }

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

      // Only handle event-related socket messages on this screen.
      if (eventName != SocketEvents.eventCreate &&
          eventName != SocketEvents.eventUpdate &&
          eventName != SocketEvents.eventDelete) {
        return;
      }

      // Guard against malformed socket payloads.
      if (eventData is! Map<String, dynamic>) {
        return;
      }

      try {
        final activeCacheKey = _buildFilterCacheKey(
          _appliedFilters,
          _activeFetchLocation,
          mode: _queryMode,
          radiusKm: _activeRadiusKm,
          viewport: _viewportQuery,
        );

        setState(() {
          if (eventName == SocketEvents.eventCreate) {
            final newEvent = Event.fromJson(eventData);
            if (_eventMatchesActiveFilters(newEvent) &&
                !_events.any((e) => e.id == newEvent.id)) {
              _events = [..._events, newEvent];
            }
          } else if (eventName == SocketEvents.eventUpdate) {
            final updatedEvent = Event.fromJson(eventData);
            final index = _events.indexWhere((e) => e.id == updatedEvent.id);
            final matches = _eventMatchesActiveFilters(updatedEvent);
            if (index != -1 && matches) {
              final nextEvents = [..._events];
              nextEvents[index] = nextEvents[index].merge(updatedEvent);
              _events = nextEvents;
              if (_selectedEvent?.id == updatedEvent.id) {
                _selectedEvent = _selectedEvent!.merge(updatedEvent);
                _selectedEventPageIndex = findExploreEventIndex(
                  _events,
                  updatedEvent.id,
                );
              }
            } else if (index != -1 && !matches) {
              _events = _events.where((e) => e.id != updatedEvent.id).toList();
              if (_selectedEvent?.id == updatedEvent.id) {
                _selectedEvent = null;
                _showDetails = false;
                _selectedEventPageIndex = 0;
              }
            } else if (matches) {
              _events = [..._events, updatedEvent];
            }
          } else if (eventName == SocketEvents.eventDelete) {
            final eventId = eventData['id'];
            _events = _events.where((e) => e.id != eventId).toList();
            if (_selectedEvent?.id == eventId) {
              _selectedEvent = null;
              _showDetails = false;
              _selectedEventPageIndex = 0;
            }
          }

          final reconciledSelectedEvent = reconcileSelectedExploreEvent(
            _events,
            _selectedEvent,
          );
          _selectedEvent = reconciledSelectedEvent;
          if (reconciledSelectedEvent == null) {
            _showDetails = false;
            _selectedEventPageIndex = 0;
          } else {
            _selectedEventPageIndex = findExploreEventIndex(
              _events,
              reconciledSelectedEvent.id,
            );
          }

          _eventCacheByFilter[activeCacheKey] = _ExploreEventCacheEntry(
            events: List<Event>.from(_events),
            nextCursor: _nextEventsCursor,
            hasNext: _hasNextEvents,
          );
        });

        if (_selectedEvent != null) {
          _syncDetailsPageToSelection();
        }

        // Invalidate tile cache on any event change and refetch.
        _invalidateTileCache();
        _refreshMarkersForCurrentState();
      } catch (e) {
        debugPrint('Explore socket event error: $e');
      }
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
    _invalidateTileCache();
    setState(() {
      _appliedFilters = _appliedFilters.copyWith(quickStatus: quickStatus);
    });
    unawaited(_refreshEventsForCurrentFilters(force: true));
    _refreshMarkersForCurrentState();
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
    _invalidateTileCache();
    setState(() {
      _appliedFilters = _draftFilters.copyWith(
        tagIds: {..._draftFilters.tagIds},
      );
      _isFilterOpen = false;
    });
    unawaited(_refreshEventsForCurrentFilters(force: true));
    _refreshMarkersForCurrentState();
  }

  void _handleViewportChanged(ExploreViewportQuery viewport) {
    _queryMode = ExploreMapQueryMode.viewport;
    _viewportQuery = viewport;
    unawaited(_refreshMarkersForViewport(viewport));
  }

  Future<void> _refreshMarkersForViewport(ExploreViewportQuery viewport) async {
    final nextIsClusterMode = viewport.zoom < clusterZoomThreshold;
    debugPrint(
      '[MARKERS] refreshMarkersForViewport zoom=${viewport.zoom.toStringAsFixed(1)} mode=${nextIsClusterMode ? "cluster" : "tile"} center=${viewport.center.latitude.toStringAsFixed(4)},${viewport.center.longitude.toStringAsFixed(4)} radiusKm=${viewport.radiusKm.toStringAsFixed(1)}',
    );

    if (nextIsClusterMode) {
      await _loadClusterMarkers(viewport);
    } else {
      await _loadTileMarkers(viewport);
    }
  }

  /// Whether the current viewport is still covered by the last cluster fetch.
  bool _isViewportCoveredByLastFetch(ExploreViewportQuery viewport) {
    final prevCenter = _lastClusterFetchCenter;
    if (prevCenter == null) return false;
    if (viewport.zoom.floor() != _lastClusterFetchZoom) return false;

    // The viewport edge must stay within the fetched zone.
    // Distance from old center to new center + new viewport radius
    // must be less than the radius we actually fetched.
    final centerDrift =
        distanceInMetersBetween(
          prevCenter.latitude,
          prevCenter.longitude,
          viewport.center.latitude,
          viewport.center.longitude,
        ) /
        1000.0;
    return (centerDrift + viewport.radiusKm) < _lastClusterFetchRadius;
  }

  Future<void> _loadClusterMarkers(ExploreViewportQuery viewport) async {
    if (_isViewportCoveredByLastFetch(viewport)) {
      debugPrint('[MARKERS] cluster fetch skipped — viewport still covered');
      if (!_isClusterMode) {
        setState(() => _isClusterMode = true);
      }
      return;
    }

    final requestVersion = ++_markerRequestVersion;
    // Over-fetch at 2x the viewport radius so small pans don't need a refetch.
    final fetchRadius = viewport.radiusKm * 2;
    debugPrint(
      '[MARKERS] loadClusterMarkers version=$requestVersion fetchRadius=${fetchRadius.toStringAsFixed(1)}km',
    );

    try {
      final clusters = await eventService.getEventClusters(
        latitude: viewport.center.latitude,
        longitude: viewport.center.longitude,
        radiusKm: fetchRadius,
        zoom: viewport.zoom.floor(),
        status: _statusQueryForFilters(_appliedFilters),
        type: _appliedFilters.eventType,
        datePreset: _appliedFilters.datePreset,
        tagIds: _appliedFilters.tagIds,
      );
      if (!mounted || requestVersion != _markerRequestVersion) {
        debugPrint(
          '[MARKERS] cluster response discarded: mounted=$mounted version=$requestVersion current=$_markerRequestVersion',
        );
        return;
      }

      debugPrint(
        '[MARKERS] cluster response applied: ${clusters.length} clusters',
      );
      setState(() {
        _isClusterMode = true;
        _serverClusters = clusters;
        _lastClusterFetchCenter = viewport.center;
        _lastClusterFetchRadius = fetchRadius;
        _lastClusterFetchZoom = viewport.zoom.floor();
      });
    } catch (e) {
      debugPrint('[MARKERS] cluster fetch FAILED: $e');
    }
  }

  Future<void> _loadTileMarkers(ExploreViewportQuery viewport) async {
    final sw = LatLng(
      viewport.center.latitude - (viewport.radiusKm / 111.0),
      viewport.center.longitude -
          (viewport.radiusKm /
              (111.0 * cos(viewport.center.latitude * pi / 180))),
    );
    final ne = LatLng(
      viewport.center.latitude + (viewport.radiusKm / 111.0),
      viewport.center.longitude +
          (viewport.radiusKm /
              (111.0 * cos(viewport.center.latitude * pi / 180))),
    );

    final neededTiles = computeVisibleGeohashTiles(
      sw: sw,
      ne: ne,
      zoom: viewport.zoom,
    );

    final missingTiles = neededTiles
        .where((tile) => !_tileCache.containsKey(tile))
        .toSet();

    if (missingTiles.isEmpty) {
      setState(() {
        _isClusterMode = false;
        _visibleMarkers = _collectMarkersFromTiles(_tileCache.keys.toSet());
      });
      return;
    }

    final requestVersion = ++_markerRequestVersion;
    // Don't flip _isClusterMode yet — keep showing old markers until tiles load.

    try {
      final tileData = await eventService.getEventMarkersByTiles(
        tiles: missingTiles,
        zoom: viewport.zoom.floor(),
        status: _statusQueryForFilters(_appliedFilters),
        type: _appliedFilters.eventType,
        datePreset: _appliedFilters.datePreset,
        tagIds: _appliedFilters.tagIds,
      );
      if (!mounted || requestVersion != _markerRequestVersion) return;

      final nextCache = Map<String, List<EventMarker>>.from(_tileCache);
      tileData.forEach((key, value) {
        nextCache[key] = value;
      });

      setState(() {
        _isClusterMode = false;
        _tileCache = nextCache;
        _visibleMarkers = _collectMarkersFromTiles(nextCache.keys.toSet());
      });
    } catch (_) {
      // Tile fetch failed — keep existing state.
    }
  }

  List<EventMarker> _collectMarkersFromTiles(Set<String> tiles) {
    final seen = <String>{};
    final markers = <EventMarker>[];
    for (final tile in tiles) {
      final tileMarkers = _tileCache[tile];
      if (tileMarkers == null) continue;
      for (final marker in tileMarkers) {
        if (seen.add(marker.id)) {
          markers.add(marker);
        }
      }
    }
    return markers;
  }

  void _selectMarkerById(String markerId) {
    // Already selected — just ensure details card is visible, don't re-trigger
    // the focus cycle which would cause unnecessary viewport changes.
    if (_selectedEvent?.id == markerId) {
      if (!_showDetails) {
        setState(() => _showDetails = true);
      }
      return;
    }

    // Check if we already have a preview cached
    final cached = _markerPreviewCache[markerId];
    if (cached != null) {
      _selectEvent(cached);
      return;
    }

    // Show loading state and fetch preview on demand
    final requestVersion = ++_selectedEventRequestVersion;
    setState(() {
      _isSelectedEventLoading = true;
      _showDetails = true;
    });

    eventService
        .getEventPreview(markerId)
        .then((preview) {
          if (!mounted || requestVersion != _selectedEventRequestVersion) {
            return;
          }
          _markerPreviewCache[markerId] = preview;
          // Increment focus ID here — now _selectedEvent and the focus request
          // update together, so _focusOnSelectedEvent fires for the correct event.
          setState(() {
            _selectedEvent = preview;
            _isSelectedEventLoading = false;
            _selectedEventFocusRequestId++;
          });
        })
        .catchError((_) {
          if (!mounted || requestVersion != _selectedEventRequestVersion) {
            return;
          }
          setState(() => _isSelectedEventLoading = false);
        });
  }

  void _invalidateTileCache() {
    // Only clear cache metadata so new fetches are forced.
    // Do NOT clear _visibleMarkers or _serverClusters here — they stay
    // visible until the replacement fetch arrives, preventing a blank flash.
    _tileCache = {};
    _markerCacheByFilter.clear();
    _lastClusterFetchCenter = null;
    _lastClusterFetchRadius = 0;
    _lastClusterFetchZoom = 0;
  }

  /// Refreshes markers for whatever state the screen is currently in:
  /// - If a viewport query is active (user has panned/zoomed), use it.
  /// - Otherwise bootstrap from the user's location in cluster mode.
  void _refreshMarkersForCurrentState() {
    if (_viewportQuery != null) {
      unawaited(_refreshMarkersForViewport(_viewportQuery!));
    } else {
      final location = _effectiveLocation;
      if (location != null) {
        unawaited(_loadClusterMarkers(ExploreViewportQuery(
          center: location,
          radiusKm: _appliedFilters.radiusKm,
          zoom: 10,
        )));
      }
    }
  }

  void _handleRecenterRequested() {
    setState(() {
      _queryMode = ExploreMapQueryMode.followLocation;
      _viewportQuery = null;
    });
    unawaited(_refreshEventsForCurrentFilters(force: true));
    _refreshMarkersForCurrentState();
  }

  void _resetDrawerFilters() {
    setState(() {
      _draftFilters = ExploreFilterState(
        quickStatus: _appliedFilters.quickStatus,
      );
    });
  }

  void _expandRadius() {
    if (_isViewportMode) {
      return;
    }

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
    await _resolveUserLocation();
    if (!mounted) return;
    if (!_isViewportMode) {
      unawaited(_refreshEventsForCurrentFilters());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVisibleEvent = _selectedVisibleEvent;
    final resolvedSelectedEvent = selectedVisibleEvent ?? _selectedEvent;
    final detailSizingEvent =
        _visibleEvents.isNotEmpty &&
            _selectedEventPageIndex >= 0 &&
            _selectedEventPageIndex < _visibleEvents.length
        ? _visibleEvents[_selectedEventPageIndex]
        : resolvedSelectedEvent;
    if (_lastMeasuredShowDetails != _showDetails ||
        _lastMeasuredFilterOpen != _isFilterOpen ||
        _lastMeasuredShowDetails == null) {
      _lastMeasuredShowDetails = _showDetails;
      _lastMeasuredFilterOpen = _isFilterOpen;
      _scheduleMapPaddingMeasurement();
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: ExploreEventMap(
              manager: _mapManager,
              eventMarkers: _useSimpleMarkerFetch
                  ? _visibleMarkers
                  : (_isClusterMode ? const [] : _visibleMarkers),
              serverClusters: _useSimpleMarkerFetch
                  ? const []
                  : (_isClusterMode ? _serverClusters : const []),
              useServerClusters: _useSimpleMarkerFetch ? false : _isClusterMode,
              selectedEvent: selectedVisibleEvent,
              selectedMarkerId: _selectedEvent?.id,
              userLocation: _effectiveLocation,
              onEventSelected: _selectEvent,
              onMarkerSelected: _selectMarkerById,
              safeAreaPadding: _mapSafeAreaPadding,
              shouldAutoFitOnContentChange: !_isViewportMode,
              selectedEventFocusRequestId: _selectedEventFocusRequestId,
              onClusterFocusStart: () {
                setState(() {
                  _showDetails = false;
                });
              },
              onViewportChanged: _handleViewportChanged,
              onRecenterRequested: _handleRecenterRequested,
            ),
          ),

          if (_isLoading) _buildLoadingOverlay(),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                key: _topOverlayKey,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExploreSearchBar(
                      onOpenFilters: _openFilters,
                      readOnly: true,
                      onTap: () => context.push(SearchScreen.routePath),
                    ),
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
              child: AnimatedSize(
                key: _detailsCardKey,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Stack(
                  children: [
                    IgnorePointer(
                      child: Opacity(
                        opacity: 0,
                        child: _buildEventDetailsCard(
                          context,
                          detailSizingEvent!,
                          status: resolveEventStatus(detailSizingEvent),
                          isSelected: true,
                          showSwipeIndicator: _visibleEvents.length > 1,
                          indicatorCurrentIndex: _selectedEventPageIndex,
                          indicatorItemCount: _visibleEvents.length,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: PageView.builder(
                        controller: _detailsPageController,
                        onPageChanged: _handleDetailsPageChanged,
                        itemCount: _visibleEvents.length,
                        itemBuilder: (context, index) {
                          final event = _visibleEvents[index];
                          final selectedEvent = event.id == _selectedEvent?.id
                              ? (_selectedVisibleEvent ?? event)
                              : event;
                          final status = resolveEventStatus(selectedEvent);

                          return _buildEventDetailsCard(
                            context,
                            selectedEvent,
                            status: status,
                            isSelected: event.id == _selectedEvent?.id,
                            showSwipeIndicator: _visibleEvents.length > 1,
                            indicatorCurrentIndex: _selectedEventPageIndex,
                            indicatorItemCount: _visibleEvents.length,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          KeyedSubtree(key: _bottomNavKey, child: const AppBottomNav()),
          if (_isFilterOpen) _buildFilterDrawer(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final shouldShowDetailsSkeleton =
        _showDetails || _selectedEvent != null || _selectedVisibleEvent != null;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
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
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          children: [
                            AppSkeleton(
                              width: 20,
                              height: 20,
                              shape: BoxShape.circle,
                            ),
                            SizedBox(width: 12),
                            Expanded(child: AppSkeletonLine(height: 14)),
                            SizedBox(width: 12),
                            AppSkeleton(
                              width: 36,
                              height: 36,
                              shape: BoxShape.circle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 4,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, index) => AppSkeleton(
                            width: index == 0 ? 92 : 76,
                            height: 40,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (shouldShowDetailsSkeleton)
              const Positioned(
                bottom: 112,
                left: 20,
                right: 20,
                child: AppCard(
                  padding: AppCardPadding.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeleton(
                            width: 80,
                            height: 80,
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSkeletonLine(width: 150, height: 18),
                                SizedBox(height: 10),
                                AppSkeletonLine(width: 110, height: 12),
                                SizedBox(height: 10),
                                AppSkeletonLine(width: 132, height: 12),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          AppSkeleton(
                            width: 32,
                            height: 32,
                            shape: BoxShape.circle,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      AppSkeletonLine(height: 12),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          AppSkeletonLine(width: 90, height: 12),
                          SizedBox(width: 16),
                          AppSkeletonLine(width: 72, height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetailsCard(
    BuildContext context,
    Event event, {
    required String status,
    required bool isSelected,
    bool showSwipeIndicator = false,
    int indicatorCurrentIndex = 0,
    int indicatorItemCount = 0,
  }) {
    return AppCard(
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
                      event.media?.firstOrNull?.url ??
                      'https://picsum.photos/seed/${event.id}/200/200',
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
                            event.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTypography.titleLG,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => _showDetails = false),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        EventStatusBadge(status: status),
                        Text(
                          'Free Entry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTypography.bodySMStrong.copyWith(
                            color: AppColors.mutedForeground,
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
                            _getRelativeTime(event.startTime, event.endTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTypography.bodyMDStrong.copyWith(
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
          if (event.tags?.isNotEmpty == true)
            SizedBox(
              height: 28,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: event.tags!.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) =>
                    _tag(event.tags![index].name.toUpperCase()),
              ),
            ),
          Row(
            children: [
              _engagementMeta(
                LucideIcons.eye,
                '${event.stats?.viewCount ?? 0} views',
              ),
              Flexible(
                child: _engagementMeta(
                  LucideIcons.star,
                  event.stats != null && event.stats!.ratingCount > 0
                      ? '${event.stats!.ratingAverage.toStringAsFixed(1)} (${event.stats!.ratingCount})'
                      : 'No ratings',
                ),
              ),
              if (isSelected && _isSelectedEventLoading)
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
                  onPressed: () => context.push(
                    EventDetailScreen.routePath.replaceAll(':id', event.id),
                    extra: event,
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
          if (showSwipeIndicator) ...[
            const SizedBox(height: 4),
            _buildDetailsIndicator(
              itemCount: indicatorItemCount,
              currentIndex: indicatorCurrentIndex,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsIndicator({
    required int itemCount,
    required int currentIndex,
  }) {
    final window = buildExploreEventCardIndicatorWindow(
      itemCount: itemCount,
      currentIndex: currentIndex,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: window.pageIndices.asMap().entries.map((entry) {
        final isActive = entry.key == window.activeDotIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: isActive ? 18 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }).toList(),
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
            style: context.appTypography.bodySMStrong.copyWith(
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
    final borderRadius = BorderRadius.circular(12);
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
                style: context.appTypography.bodySMSemi.copyWith(
                  color: AppColors.primary,
                ),
                children: [
                  TextSpan(text: message),
                  if (hasAction) const TextSpan(text: ' '),
                  if (hasAction)
                    TextSpan(
                      text: ctaLabel,
                      recognizer: TapGestureRecognizer()..onTap = onTap,
                      style: context.appTypography.bodySMExtraBold.copyWith(
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

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Ink(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.42),
                    AppColors.warning.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: content,
            ),
          ),
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

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: context.appTypography.labelSM),
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
            style: context.appTypography.bodySMStrong.copyWith(
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
                      Text(
                        'Filter Events',
                        style: context.appTypography.titleLG,
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
                          style: context.appTypography.bodyMDStrong,
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
                            final selected =
                                _draftFilters.eventType == option.value ||
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
                          Text(
                            'Categories are unavailable right now.',
                            style: context.appTypography.bodyBase,
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
    return Text(text, style: context.appTypography.overline);
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
        style: context.appTypography.bodyMDStrong.copyWith(
          color: selected ? AppColors.surface : AppColors.primary,
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('=== EXPLORE SCREEN DISPOSED ===');
    debugPrint('Stack: ${StackTrace.current}');
    _socketSubscription?.cancel();
    _detailsPageController.dispose();
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
