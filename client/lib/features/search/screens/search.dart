import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../events/models/event.dart';
import '../../events/models/search_event_item.dart';
import '../../profile/models/user.dart';
import '../../../shared/providers/tag.dart';
import '../../../shared/providers/user.dart';
import '../../events/services/event.dart';
import '../services/search.dart';
import '../services/search_history.dart';
import '../../../shared/theme/theme.dart';
import '../../events/utils/event_status.dart';
import '../../explore/utils/explore_filters.dart';
import '../../../shared/widgets/button.dart';
import '../../events/widgets/event_search_result_tile.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/app_search_bar.dart';
import '../../events/screens/event_detail.dart';
import '../../explore/screens/explore_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.historyService});

  static const String routePath = '/search';

  final SearchHistoryService? historyService;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const int _pageSize = 20;
  static const int _recentItemLimit = 10;
  static const List<_QuickStatusOption> _quickStatusOptions = [
    _QuickStatusOption(EventStatusValue.all, 'All'),
    _QuickStatusOption(EventStatusValue.ongoing, 'Ongoing'),
    _QuickStatusOption(EventStatusValue.upcoming, 'Upcoming'),
  ];
  static const List<_EventTypeOption> _eventTypeOptions = [
    _EventTypeOption(null, 'Any Type'),
    _EventTypeOption(ExploreEventTypeValues.organized, 'Organized'),
    _EventTypeOption(ExploreEventTypeValues.custom, 'Custom'),
  ];
  static const List<_DatePresetOption> _datePresetOptions = [
    _DatePresetOption(ExploreDatePresetValues.anytime, 'Anytime'),
    _DatePresetOption(ExploreDatePresetValues.today, 'Today'),
    _DatePresetOption(ExploreDatePresetValues.thisWeek, 'This Week'),
    _DatePresetOption(ExploreDatePresetValues.thisMonth, 'This Month'),
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final SearchHistoryService _historyService;

  Timer? _debounce;
  ExploreFilterState _appliedFilters = const ExploreFilterState();
  List<SearchEventItem> _historyItems = const [];
  List<SearchEventItem> _recentItems = const [];
  List<SearchEventItem> _searchResults = const [];
  bool _isLoadingLanding = true;
  bool _isSearching = false;
  bool _isFetchingMore = false;
  bool _hasNextSearch = false;
  String? _searchNextCursor;
  String? _landingErrorMessage;
  String? _searchErrorMessage;
  int _landingRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _historyService = widget.historyService ?? searchHistoryService;
    _controller.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_loadLandingData());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isLandingState => _controller.text.trim().isEmpty;
  bool get _isQueryTooShort {
    final query = _controller.text.trim();
    return query.isNotEmpty && query.length < 2;
  }

  UserAddress? get _currentUserAddress =>
      ref.read(userProfileProvider).value?.address;

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLandingState ||
        _isQueryTooShort ||
        _isSearching ||
        _isFetchingMore ||
        !_hasNextSearch) {
      return;
    }

    if (_scrollController.position.extentAfter < 320) {
      unawaited(_searchEvents());
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchErrorMessage = null;
        _searchNextCursor = null;
        _hasNextSearch = false;
        _isSearching = false;
        _isFetchingMore = false;
      });
      unawaited(_loadLandingData(showLoading: false));
      return;
    }

    if (query.length < 2) {
      setState(() {
        _searchResults = const [];
        _searchErrorMessage = null;
        _searchNextCursor = null;
        _hasNextSearch = false;
        _isSearching = false;
        _isFetchingMore = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      unawaited(_searchEvents(refresh: true));
    });
  }

  Future<void> _loadLandingData({bool showLoading = true}) async {
    final requestVersion = ++_landingRequestVersion;
    final shouldShowLoader =
        showLoading ||
        (_historyItems.isEmpty &&
            _recentItems.isEmpty &&
            _landingErrorMessage == null);

    if (shouldShowLoader) {
      setState(() {
        _isLoadingLanding = true;
        _landingErrorMessage = null;
      });
    }

    try {
      final historyFuture = _historyService.getHistory();
      final recentFuture = eventService.getEvents(
        status: _suggestedStatusQuery(),
        type: _appliedFilters.eventType,
        datePreset:
            _appliedFilters.datePreset == ExploreDatePresetValues.anytime
            ? null
            : _appliedFilters.datePreset,
        latitude: _currentUserAddress?.latitude,
        longitude: _currentUserAddress?.longitude,
        radiusKm: _hasCurrentCoordinates ? _appliedFilters.radiusKm : null,
        tagIds: _appliedFilters.tagIds.isEmpty ? null : _appliedFilters.tagIds,
        limit: _recentItemLimit,
        sortBy: 'createdAt',
        sortOrder: 'desc',
      );

      final values = await Future.wait([historyFuture, recentFuture]);
      if (!mounted || requestVersion != _landingRequestVersion) return;

      final history = values[0] as List<SearchEventItem>;
      final recentResponse = values[1] as dynamic;
      final recentItems = (recentResponse.items as List<Event>)
          .map(SearchEventItem.fromEvent)
          .toList();

      setState(() {
        _historyItems = history;
        _recentItems = recentItems;
        _isLoadingLanding = false;
        _landingErrorMessage = null;
      });
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted || requestVersion != _landingRequestVersion) return;
      setState(() {
        _isLoadingLanding = false;
        _landingErrorMessage = 'Unable to load recent events right now.';
      });
    }
  }

  bool get _hasCurrentCoordinates =>
      _currentUserAddress?.latitude != null &&
      _currentUserAddress?.longitude != null;

  Future<void> _searchEvents({bool refresh = false}) async {
    if ((_isSearching && !refresh) || _isFetchingMore) {
      return;
    }

    final query = _controller.text.trim();
    if (query.length < 2) {
      return;
    }

    if (refresh) {
      setState(() {
        _isSearching = true;
        _isFetchingMore = false;
        _searchResults = const [];
        _searchErrorMessage = null;
        _searchNextCursor = null;
        _hasNextSearch = false;
      });
    } else {
      if (!_hasNextSearch) return;
      setState(() => _isFetchingMore = true);
    }

    try {
      final response = await searchService.search(
        query,
        next: refresh ? null : _searchNextCursor,
        limit: _pageSize,
        // filters: _buildSearchQueryParameters(),
      );
      if (!mounted) return;

      final nextItems = response.items
          .map(SearchEventItem.fromSearchResult)
          .toList();
      final merged = <String, SearchEventItem>{
        for (final item in refresh ? <SearchEventItem>[] : _searchResults)
          item.id: item,
        for (final item in nextItems) item.id: item,
      }.values.toList();

      setState(() {
        _searchResults = merged;
        _searchNextCursor = response.pagination.next;
        _hasNextSearch = response.pagination.hasNext;
        _isSearching = false;
        _isFetchingMore = false;
        _searchErrorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _isFetchingMore = false;
        _searchErrorMessage = 'Unable to search events right now.';
      });
    }
  }

  // Search filter query params are temporarily disabled.
  // Restore `_buildSearchQueryParameters()` when the search API params are
  // ready to be re-enabled.

  String _suggestedStatusQuery() {
    if (_appliedFilters.quickStatus == EventStatusValue.all) {
      return '${EventStatusValue.upcoming},${EventStatusValue.ongoing}';
    }
    return _appliedFilters.quickStatus;
  }

  Future<void> _openFilters() async {
    final cachedTags = ref.read(tagsProvider(rootOnly: true)).value;
    List<Tag> rootTags = cachedTags ?? const <Tag>[];
    if (cachedTags == null) {
      try {
        rootTags = await ref.read(tagsProvider(rootOnly: true).future);
      } catch (_) {
        rootTags = const <Tag>[];
      }
    }
    if (!mounted) return;
    final nextFilters = await showModalBottomSheet<ExploreFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => _SearchFilterSheet(
        initialFilters: _appliedFilters,
        rootTags: rootTags,
      ),
    );

    if (!mounted || nextFilters == null) return;
    setState(() {
      _appliedFilters = nextFilters;
    });

    if (_isLandingState) {
      await _loadLandingData();
    } else {
      await _searchEvents(refresh: true);
    }
  }

  Future<void> _openEvent(SearchEventItem item) async {
    await _historyService.addSelection(item);
    if (!mounted) return;
    setState(() {
      _historyItems = <SearchEventItem>[
        item,
        ..._historyItems.where((entry) => entry.id != item.id),
      ].take(10).toList();
    });
    await context.push(EventDetailScreen.routePath.replaceAll(':id', item.id));
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go(ExploreScreen.routePath);
  }

  String _distanceLabel(SearchEventItem item) {
    final userLat = _currentUserAddress?.latitude;
    final userLng = _currentUserAddress?.longitude;
    final eventLat = item.location.latitude;
    final eventLng = item.location.longitude;

    if (userLat == null ||
        userLng == null ||
        eventLat == null ||
        eventLng == null) {
      return 'Distance unavailable';
    }

    final distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLng,
      eventLat,
      eventLng,
    );
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km away';
    }
    return '${distanceInMeters.round()} m away';
  }

  String _createdAgoLabel(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _handleBack,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.chevronLeft,
                  size: AppIconSizes.defaultSize,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppSearchBar(
                controller: _controller,
                placeholder: 'Find food events...',
                onOpenFilters: _openFilters,
                autofocus: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandingBody() {
    if (_isLoadingLanding) {
      return _buildLoadingState(showSections: true);
    }

    if (_landingErrorMessage != null) {
      return _buildMessageState(
        icon: LucideIcons.cloudOff,
        title: _landingErrorMessage!,
        subtitle: 'Pull down to try again.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLandingData,
      color: AppColors.primary,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          _buildSection(
            title: 'Recent searches',
            items: _historyItems,
            emptyLabel: 'No local search history yet.',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Recently added',
            items: _recentItems,
            emptyLabel: 'No upcoming or ongoing events available right now.',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody() {
    if (_isQueryTooShort) {
      return _buildMessageState(
        icon: LucideIcons.search,
        title: 'Type at least 2 characters',
        subtitle: 'Search starts after two letters.',
      );
    }

    if (_isSearching && _searchResults.isEmpty) {
      return _buildLoadingState(showSections: false);
    }

    if (_searchErrorMessage != null && _searchResults.isEmpty) {
      return _buildMessageState(
        icon: LucideIcons.cloudOff,
        title: _searchErrorMessage!,
        subtitle: 'Try again in a moment.',
      );
    }

    if (_searchResults.isEmpty) {
      return _buildMessageState(
        icon: LucideIcons.searchX,
        title: 'No matching events found',
        subtitle: 'Try a different search or adjust filters.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _searchEvents(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        itemCount: _searchResults.length + 1,
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            if (_isFetchingMore) {
              return const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 12),
                child: Center(child: AppSkeletonLine(width: 80, height: 8)),
              );
            }
            return const SizedBox(height: 12);
          }

          final item = _searchResults[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventSearchResultTile(
              key: ValueKey('search-event-${item.id}'),
              item: item,
              distanceLabel: _distanceLabel(item),
              createdAgoLabel: _createdAgoLabel(item.createdAt),
              onTap: () => _openEvent(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<SearchEventItem> items,
    required String emptyLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.appTypography.heading3Strong.copyWith(
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: context.appTypography.bodyMD.copyWith(
              color: AppColors.mutedForeground,
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EventSearchResultTile(
                key: ValueKey('section-event-$title-${item.id}'),
                item: item,
                distanceLabel: _distanceLabel(item),
                createdAgoLabel: _createdAgoLabel(item.createdAt),
                onTap: () => _openEvent(item),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.hero,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.appTypography.titleMD.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: context.appTypography.bodyMD.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState({required bool showSections}) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        if (showSections) ...[
          const AppSkeletonLine(width: 140, height: 18),
          const SizedBox(height: 12),
          ...List.generate(2, (_) => _buildSearchSkeletonTile()),
          const SizedBox(height: 24),
          const AppSkeletonLine(width: 136, height: 18),
          const SizedBox(height: 12),
        ],
        ...List.generate(
          showSections ? 3 : 5,
          (_) => _buildSearchSkeletonTile(),
        ),
      ],
    );
  }

  Widget _buildSearchSkeletonTile() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AppSkeleton(width: 48, height: 48, shape: BoxShape.circle),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppSkeleton(width: 76, height: 24),
                        SizedBox(width: 10),
                        Expanded(child: AppSkeletonLine(height: 16)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: AppSkeletonLine(width: 120)),
                        SizedBox(width: 12),
                        AppSkeletonLine(width: 72),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isLandingState ? _buildLandingBody() : _buildSearchBody(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({
    required this.initialFilters,
    required this.rootTags,
  });

  final ExploreFilterState initialFilters;
  final List<Tag> rootTags;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late ExploreFilterState _draftFilters;

  @override
  void initState() {
    super.initState();
    _draftFilters = widget.initialFilters;
  }

  void _reset() {
    setState(() {
      _draftFilters = const ExploreFilterState();
    });
  }

  void _toggleTag(String tagId) {
    final next = {..._draftFilters.tagIds};
    if (!next.add(tagId)) {
      next.remove(tagId);
    }
    setState(() {
      _draftFilters = _draftFilters.copyWith(tagIds: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Events',
                  style: context.appTypography.titleLG.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('STATUS'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _SearchScreenState._quickStatusOptions.map((
                      option,
                    ) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _draftFilters = _draftFilters.copyWith(
                              quickStatus: option.value,
                            );
                          });
                        },
                        child: _chipButton(
                          option.label,
                          selected: _draftFilters.quickStatus == option.value,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('DISTANCE'),
                  const SizedBox(height: 16),
                  Text(
                    '${_draftFilters.radiusKm.toStringAsFixed(0)} km',
                    style: context.appTypography.bodyMDStrong.copyWith(
                      color: AppColors.primary,
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
                    children: _SearchScreenState._eventTypeOptions.map((
                      option,
                    ) {
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
                        child: _chipButton(option.label, selected: selected),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('TIME'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _SearchScreenState._datePresetOptions.map((
                      option,
                    ) {
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
                          selected: _draftFilters.datePreset == option.value,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('CATEGORIES'),
                  const SizedBox(height: 12),
                  if (widget.rootTags.isEmpty)
                    Text(
                      'Categories are unavailable right now.',
                      style: context.appTypography.bodyBase.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.rootTags.map((tag) {
                        return GestureDetector(
                          onTap: () => _toggleTag(tag.id),
                          child: _chipButton(
                            tag.name,
                            selected: _draftFilters.tagIds.contains(tag.id),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.lg,
                    label: 'Reset',
                    onPressed: _reset,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    size: AppButtonSize.lg,
                    label: 'Apply Filters',
                    onPressed: () => Navigator.of(context).pop(_draftFilters),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: context.appTypography.overline.copyWith(
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
        style: context.appTypography.bodyMDStrong.copyWith(
          color: selected ? AppColors.surface : AppColors.primary,
        ),
      ),
    );
  }
}

class _QuickStatusOption {
  const _QuickStatusOption(this.value, this.label);

  final String value;
  final String label;
}

class _EventTypeOption {
  const _EventTypeOption(this.value, this.label);

  final String? value;
  final String label;
}

class _DatePresetOption {
  const _DatePresetOption(this.value, this.label);

  final String value;
  final String label;
}
