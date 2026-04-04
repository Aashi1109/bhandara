import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/chat.dart';
import '../screens/chat.dart';
import '../screens/event_detail.dart';
import '../screens/profile.dart';
import '../screens/thread.dart';
import '../services/save.dart';
import '../services/search.dart';
import '../theme/theme.dart';
import '../utils/event_status.dart';
import '../widgets/app_pull_to_refresh.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/card.dart';
import 'explore/widgets/explore_search_bar.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  static const String routePath = '/saved';

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  static const int _pageSize = 20;
  static const _filters = ['All', 'Events', 'Threads', 'Messages', 'Profiles'];

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
      case 'Profiles':
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
      return AppPullToRefresh(
        onRefresh: () => _loadSavedResults(refresh: true),
        wrapInScrollView: false,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          children: [
            const SizedBox(height: 120),
            const Icon(
              LucideIcons.searchX,
              size: AppIconSizes.hero,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No saved items found',
                style: context.appTypography.titleSM.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Try a different search or filter',
                style: context.appTypography.bodyMD.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      wrapInScrollView: false,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: _results.length + 1,
        itemBuilder: (context, index) {
          if (index == _results.length) {
            if (_isFetchingMore) {
              return const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox(height: 12);
          }

          final result = _results[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => _openSavedItem(result),
              child: _buildResultCard(result),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultCard(SearchResult result) {
    final metadata = result.metadata ?? const <String, dynamic>{};
    final address = metadata['address'] as String?;
    final rawStart = metadata['start'] as String?;
    final rawEnd = metadata['end'] as String?;
    final rawStatus = metadata['status'] as String?;
    final createdAt = metadata['createdAt'] as String?;
    final username = metadata['username'] as String?;
    final bio = metadata['bio'] as String?;
    final startTime = rawStart != null ? DateTime.tryParse(rawStart) : null;
    final endTime = rawEnd != null ? DateTime.tryParse(rawEnd) : null;
    final createdAtTime = createdAt != null
        ? DateTime.tryParse(createdAt)
        : null;
    final resolvedStatus =
        result.type == 'event' && startTime != null && endTime != null
        ? deriveEventStatus(
            startTime: startTime,
            endTime: endTime,
            currentStatus: rawStatus,
          )
        : null;
    final isMessage = result.type == 'message';
    final secondaryText = startTime != null
        ? '${_formatTime(startTime)}${address != null && address.isNotEmpty ? ' • $address' : ''}'
        : result.type == 'user'
        ? (username != null && username.isNotEmpty ? '@$username' : bio)
        : result.description;

    return AppCard(
      padding: AppCardPadding.none,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 16,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: result.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: result.imageUrl!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _placeholderImage(result),
                    )
                  : _placeholderImage(result),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildBadge(
                        label: result.type == 'user'
                            ? 'PROFILE'
                            : result.type.toUpperCase(),
                        background: AppColors.primary.withValues(alpha: 0.1),
                        foreground: AppColors.primary,
                      ),
                      if (resolvedStatus != null)
                        _buildBadge(
                          label: formatEventStatusLabel(
                            resolvedStatus,
                          ).toUpperCase(),
                          background: _statusBackground(resolvedStatus),
                          foreground: _statusForeground(resolvedStatus),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMessage
                        ? (result.description ?? 'Open message')
                        : result.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (isMessage
                                ? context.appTypography.titleXS
                                : context.appTypography.titleSM)
                            .copyWith(
                              fontWeight: isMessage
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              height: 1.25,
                              color: AppColors.primary,
                            ),
                  ),
                  if (!isMessage && secondaryText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      secondaryText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTypography.bodySM.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                  if (isMessage && createdAtTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatRelative(createdAtTime),
                      style: context.appTypography.captionSM.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: context.appTypography.labelXS.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: foreground,
        ),
      ),
    );
  }

  Color _statusBackground(String status) {
    switch (status) {
      case EventStatusValue.ongoing:
        return AppColors.success.withValues(alpha: 0.14);
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
        return AppColors.muted;
      case EventStatusValue.upcoming:
      default:
        return AppColors.warning.withValues(alpha: 0.14);
    }
  }

  Color _statusForeground(String status) {
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

  Widget _placeholderImage(SearchResult result) {
    return Container(
      width: 96,
      height: 96,
      color: AppColors.muted,
      child: Icon(
        result.type == 'event'
            ? LucideIcons.calendar
            : result.type == 'message'
            ? LucideIcons.messageCircle
            : result.type == 'user'
            ? LucideIcons.user
            : LucideIcons.messagesSquare,
        size: AppIconSizes.xl,
        color: AppColors.mutedForeground,
      ),
    );
  }

  Widget _buildErrorState() {
    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      wrapInScrollView: false,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        children: [
          const SizedBox(height: 120),
          const Icon(
            LucideIcons.cloudOff,
            size: AppIconSizes.hero,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unable to load saved items right now.',
            style: context.appTypography.titleSM.copyWith(
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _loadSavedResults(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppPullToRefresh(
      onRefresh: () => _loadSavedResults(refresh: true),
      wrapInScrollView: false,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        children: [
          const SizedBox(height: 120),
          const Icon(
            LucideIcons.search,
            size: AppIconSizes.hero,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No saved items yet',
              style: context.appTypography.titleSM.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Save events, threads, messages, and profiles to find them here',
              style: context.appTypography.bodyMD.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        border: selected ? null : Border.all(color: AppColors.border),
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
        style: context.appTypography.bodySM.copyWith(
          fontWeight: FontWeight.w700,
          color: selected
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        'Saved',
                        style: context.appTypography.heading3.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ExploreSearchBar(
                      controller: _controller,
                      placeholder: 'Search saved items...',
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _filters.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeFilter = filter;
                                });
                                _loadSavedResults(refresh: true);
                              },
                              child: _chipBtn(filter, _activeFilter == filter),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _errorMessage != null
                    ? _buildErrorState()
                    : _hasSearched || _results.isNotEmpty
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
