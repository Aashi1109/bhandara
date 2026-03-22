import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat.dart';
import '../theme/theme.dart';
import '../widgets/app_pull_to_refresh.dart';
import '../widgets/card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/explore_search_bar.dart';
import '../services/save.dart';
import '../services/search.dart';
import '../utils/event_status.dart';

import 'explore.dart';
import 'chat.dart';
import 'event_detail.dart';
import 'thread.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static const String routePath = '/search';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  List<SearchResult> _savedResults = [];
  List<String> _suggestions = [];
  bool _isLoading = true;
  bool _hasSearched = false;
  int _totalResults = 0;
  String _activeFilter = 'All Results';
  String? _errorMessage;
  Timer? _debounce;

  static const _filters = ['All Results', 'Events', 'Users', 'Tags'];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _loadSavedResults();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    final filtered = _applyFilters(query);
    if (query.isEmpty) {
      setState(() {
        _results = filtered;
        _suggestions = _buildSuggestionsList(query);
        _hasSearched = false;
        _totalResults = filtered.length;
      });
      return;
    }
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _results = filtered;
          _suggestions = _buildSuggestionsList(query);
          _hasSearched = true;
          _totalResults = filtered.length;
        });
      });
    }
  }

  Future<void> _loadSavedResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await saveService.getSavedResults();
      if (!mounted) return;
      setState(() {
        _savedResults = results;
        _results = _applyFilters(_controller.text.trim());
        _suggestions = _buildSuggestionsList(_controller.text.trim());
        _totalResults = _results.length;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load saved items right now.';
      });
    }
  }

  List<SearchResult> _applyFilters(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    return _savedResults.where((result) {
      final matchesFilter =
          _activeFilter == 'All Results' ||
          (_activeFilter == 'Events' && result.type == 'event') ||
          (_activeFilter == 'Users' && result.type == 'message') ||
          (_activeFilter == 'Tags' && result.type == 'thread');
      if (!matchesFilter) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final metadata = result.metadata ?? const <String, dynamic>{};
      final haystack = [
        result.title,
        result.description,
        metadata['address'],
        metadata['threadType'],
        metadata['description'],
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  List<String> _buildSuggestionsList(String query) {
    if (query.trim().length < 2) {
      return const [];
    }

    return _savedResults
        .map((result) => result.title.trim())
        .where((title) => title.isNotEmpty)
        .where(
          (title) => title.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toSet()
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
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
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(ExploreScreen.routePath),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.04,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.arrowLeft,
                              size: AppIconSizes.defaultSize,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ExploreSearchBar(
                            controller: _controller,
                            placeholder: 'Search events, people, tags...',
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Filter chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _filters.map((f) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeFilter = f;
                                  _results = _applyFilters(
                                    _controller.text.trim(),
                                  );
                                  _totalResults = _results.length;
                                  _suggestions = _buildSuggestionsList(
                                    _controller.text.trim(),
                                  );
                                  _hasSearched =
                                      _controller.text.trim().length >= 2;
                                });
                              },
                              child: _chipBtn(f, _activeFilter == f),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _errorMessage != null
                    ? _buildErrorState()
                    : _suggestions.isNotEmpty && !_hasSearched
                    ? _buildSuggestions()
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

  Widget _buildSuggestions() {
    return AppPullToRefresh(
      onRefresh: _loadSavedResults,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        children: [
          for (final suggestion in _suggestions)
            ListTile(
              leading: const Icon(
                LucideIcons.search,
                color: AppColors.mutedForeground,
              ),
              title: Text(
                suggestion,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                _controller.text = suggestion;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: suggestion.length),
                );
                _onQueryChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return AppPullToRefresh(
        onRefresh: _loadSavedResults,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.searchX,
                size: AppIconSizes.hero,
                color: AppColors.mutedForeground,
              ),
              SizedBox(height: 16),
              Text(
                'No results found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppPullToRefresh(
      onRefresh: _loadSavedResults,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          ..._results.map((result) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  _openSavedItem(result);
                },
                child: _buildResultCard(result),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultCard(SearchResult result) {
    final metadata = result.metadata ?? const <String, dynamic>{};
    final address = metadata['address'] as String?;
    final rawStart = metadata['start'] as String?;
    final rawEnd = metadata['end'] as String?;
    final rawStatus = metadata['status'] as String?;
    final startTime = rawStart != null ? DateTime.tryParse(rawStart) : null;
    final endTime = rawEnd != null ? DateTime.tryParse(rawEnd) : null;
    final resolvedStatus =
        result.type == 'event' && startTime != null && endTime != null
        ? deriveEventStatus(
            startTime: startTime,
            endTime: endTime,
            currentStatus: rawStatus,
          )
        : null;
    final secondaryText = startTime != null
        ? '${_formatTime(startTime)}${address != null && address.isNotEmpty ? ' • $address' : ''}'
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
                        label: result.type.toUpperCase(),
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
                    result.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                  if (result.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      secondaryText ?? result.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
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
        style: TextStyle(
          fontSize: 8,
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
            : LucideIcons.messagesSquare,
        size: AppIconSizes.xl,
        color: AppColors.mutedForeground,
      ),
    );
  }

  Widget _buildErrorState() {
    return AppPullToRefresh(
      onRefresh: _loadSavedResults,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.cloudOff,
              size: AppIconSizes.hero,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to load saved items right now.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadSavedResults,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppPullToRefresh(
      onRefresh: _loadSavedResults,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.search,
              size: AppIconSizes.hero,
              color: AppColors.mutedForeground,
            ),
            SizedBox(height: 16),
            Text(
              'Search your saved items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Type at least 2 characters to search',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  void _openSavedItem(SearchResult result) {
    if (result.type == 'event') {
      context.go(EventDetailScreen.routePath.replaceAll(':id', result.id));
      return;
    }

    if (result.type == 'thread') {
      context.go(
        ChatScreen.routePath.replaceAll(':id', result.id),
        extra: {'eventId': result.metadata?['eventId'] as String?},
      );
      return;
    }

    if (result.type == 'message') {
      final rawMessage = result.metadata?['message'];
      final threadId = result.metadata?['threadId'] as String?;
      context.go(
        ThreadScreen.routePath.replaceAll(':id', result.id),
        extra: {
          'threadId': threadId,
          'message': rawMessage is Map<String, dynamic>
              ? Message.fromJson(rawMessage)
              : null,
        },
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
