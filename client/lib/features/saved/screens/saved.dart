import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../chat/models/chat.dart';
import '../../chat/screens/chat.dart';
import '../../events/screens/event_detail.dart';
import '../../explore/screens/explore_screen.dart';
import '../../profile/screens/profile.dart';
import '../../chat/screens/thread.dart';
import '../services/save.dart';
import '../../search/services/search.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_pull_to_refresh.dart';
import '../../../shared/widgets/app_search_bar.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/skeleton.dart';
import '../widgets/saved_result_tile.dart';
import '../widgets/saved_state_view.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  static const String routePath = '/saved';

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  static const int _pageSize = 20;
  static const _filters = ['All', 'Events', 'Threads', 'Messages', 'People'];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SearchResult> _results = const [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasNext = true;
  bool _hasSearched = false;
  String _activeFilter = 'All';
  String? _errorMessage;
  String? _nextCursor;
  Timer? _debounce;
  final Set<String> _unsavingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
    _loadSavedResults(refresh: true);
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

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isFetchingMore ||
        !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 320) {
      _loadSavedResults();
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty || query.length >= 2) {
      _debounce = Timer(
        query.isEmpty ? Duration.zero : const Duration(milliseconds: 300),
        () {
          if (!mounted) return;
          _loadSavedResults(refresh: true);
        },
      );
    }
  }

  String? _activeEntityType() {
    switch (_activeFilter) {
      case 'Events':
        return 'event';
      case 'Threads':
        return 'thread';
      case 'Messages':
        return 'message';
      case 'People':
        return 'user';
      default:
        return null;
    }
  }

  Future<void> _loadSavedResults({bool refresh = false}) async {
    if ((_isLoading && !refresh) || _isFetchingMore) return;
    final trimmedQuery = _controller.text.trim();
    final effectiveQuery = trimmedQuery.length >= 2 ? trimmedQuery : null;

    if (refresh) {
      setState(() {
        _isLoading = true;
        _isFetchingMore = false;
        _errorMessage = null;
        _nextCursor = null;
        _hasNext = true;
      });
    } else {
      if (!_hasNext) return;
      setState(() => _isFetchingMore = true);
    }

    try {
      final response = await saveService.getSavedResults(
        limit: _pageSize,
        next: refresh ? null : _nextCursor,
        query: effectiveQuery,
        entityType: _activeEntityType(),
      );
      if (!mounted) return;

      final merged = <String, SearchResult>{
        for (final result in refresh ? <SearchResult>[] : _results)
          '${result.type}:${result.id}': result,
        for (final result in response.items)
          '${result.type}:${result.id}': result,
      }.values.toList();

      setState(() {
        _results = merged;
        _nextCursor = response.pagination.next;
        _hasNext = response.pagination.hasNext;
        _errorMessage = null;
        _isLoading = false;
        _isFetchingMore = false;
        _hasSearched = effectiveQuery != null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
        _errorMessage = 'Unable to load saved items right now.';
        _hasSearched = effectiveQuery != null;
      });
    }
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return _buildSearchEmptyState();
    }

    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      wrapInScrollView: false,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
        itemCount: _results.length + (_hasSearched ? 2 : 1),
        itemBuilder: (context, index) {
          if (_hasSearched && index == 0) return _buildSearchResultsHeading();

          final resultIndex = index - (_hasSearched ? 1 : 0);
          if (resultIndex == _results.length) {
            return _isFetchingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: AppSkeletonLine(width: 80, height: 8)),
                  )
                : const SizedBox(height: 12);
          }

          final result = _results[resultIndex];
          return SavedResultTile(
            result: result,
            secondaryText: _secondaryText(result),
            isUnsaving: _unsavingIds.contains(result.id),
            onTap: () => _openSavedItem(result),
            onUnsave: () => _unsaveResult(result),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsHeading() {
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Search results', style: context.appTypography.titleMDStrong),
          Text(
            '${_results.length} ${_results.length == 1 ? 'item' : 'items'}',
            style: context.appTypography.captionMD.copyWith(
              color: context.appPalette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() => const SavedLoadingList();

  String? _secondaryText(SearchResult result) {
    final metadata = result.metadata ?? const <String, dynamic>{};
    final rawStart = metadata['start'] as String?;
    final createdAt = metadata['createdAt'] as String?;
    final username = metadata['username'] as String?;
    final bio = metadata['bio'] as String?;
    final address = metadata['address'] as String?;
    final startTime = rawStart == null ? null : DateTime.tryParse(rawStart);
    final createdAtTime = createdAt == null
        ? null
        : DateTime.tryParse(createdAt);

    if (startTime != null) {
      return '${_formatTime(startTime)}${address?.isNotEmpty == true ? ' • $address' : ''}';
    }
    if (result.type == 'user') {
      return username?.isNotEmpty == true ? '@$username' : bio;
    }
    if (result.type == 'message' && createdAtTime != null) {
      return _formatRelative(createdAtTime);
    }
    return result.description;
  }

  Future<void> _unsaveResult(SearchResult result) async {
    if (_unsavingIds.contains(result.id)) return;
    setState(() => _unsavingIds.add(result.id));

    try {
      await saveService.unsaveEntity(result.type, result.id);
      if (!mounted) return;
      setState(() {
        _results = _results.where((item) => item.id != result.id).toList();
        _unsavingIds.remove(result.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unsavingIds.remove(result.id));
    }
  }

  Widget _buildErrorState() {
    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      child: SavedStateView(
        icon: LucideIcons.cloudOff,
        title: 'Couldn’t load saved items',
        description:
            'Check your connection and try again. Your items are still safe.',
        actionLabel: 'Try again',
        onAction: () => _loadSavedResults(refresh: true),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      child: SavedStateView(
        icon: LucideIcons.bookmark,
        title: 'Nothing saved yet',
        description: 'Keep events, people, and conversations close for later.',
        actionLabel: 'Explore',
        onAction: () => context.go(ExploreScreen.routePath),
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      child: SavedStateView(
        icon: LucideIcons.searchX,
        title: 'No saved items found',
        description: 'Try a different search or filter.',
        actionLabel: 'Clear search',
        onAction: () {
          _controller.clear();
          setState(() => _activeFilter = 'All');
          _loadSavedResults(refresh: true);
        },
      ),
    );
  }

  void _openSavedItem(SearchResult result) {
    if (result.type == 'event') {
      context.push(EventDetailScreen.routePath.replaceAll(':id', result.id));
      return;
    }

    if (result.type == 'thread') {
      context.push(
        ChatScreen.routePath.replaceAll(':id', result.id),
        extra: {'eventId': result.metadata?['eventId'] as String?},
      );
      return;
    }

    if (result.type == 'message') {
      final rawMessage = result.metadata?['message'];
      final threadId = result.metadata?['threadId'] as String?;
      context.push(
        ThreadScreen.routePath.replaceAll(':id', result.id),
        extra: {
          'threadId': threadId,
          'message': rawMessage is Map<String, dynamic>
              ? Message.fromJson(rawMessage)
              : null,
        },
      );
      return;
    }

    if (result.type == 'user') {
      context.push(ProfileScreen.routePath, extra: {'userId': result.id});
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatRelative(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _chipBtn(String text, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? context.appPalette.primary : context.appPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? context.appPalette.primary : context.appPalette.border,
        ),
      ),
      child: Text(
        text,
        style: context.appTypography.bodySMStrong.copyWith(
          color: selected ? context.appPalette.surface : context.appPalette.mutedForeground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 64,
                  child: Center(
                    child: Text(
                      'Saved',
                      style: context.appTypography.heading3Strong.copyWith(
                        color: context.appPalette.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppSearchBar(
                  controller: _controller,
                  placeholder: 'Search saved items…',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _activeFilter = filter);
                        _loadSavedResults(refresh: true);
                      },
                      child: _chipBtn(filter, _activeFilter == filter),
                    );
                  },
                ),
              ),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                    ? _buildErrorState()
                    : _hasSearched ||
                          _activeFilter != 'All' ||
                          _results.isNotEmpty
                    ? _buildResults()
                    : _buildEmptyState(),
              ),
            ],
          ),
          const AppBottomNav(),
        ],
      ),
    );
  }
}
