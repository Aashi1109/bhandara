import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme.dart';
import '../widgets/input.dart';
import '../widgets/card.dart';
import '../widgets/bottom_nav.dart';
import '../services/search.dart';

import 'explore.dart';
import 'event_detail.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static const String routePath = '/search';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _totalResults = 0;
  String _activeFilter = 'All Results';
  Timer? _debounce;

  static const _filters = ['All Results', 'Events', 'Users', 'Tags'];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _suggestions = [];
        _hasSearched = false;
      });
      return;
    }
    if (query.length >= 2) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _fetchSuggestions(query);
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final res = await searchService.getSuggestions(query);
      if (mounted) setState(() => _suggestions = res);
    } catch (_) {}
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      return;
    }
    _debounce?.cancel();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _suggestions = [];
    });

    final filters = _activeFilter != 'All Results'
        ? {'filters[types]': _activeFilter.toLowerCase()}
        : null;

    try {
      final res = await searchService.search(query.trim(), filters: filters);
      if (mounted) {
        setState(() {
          _results = res.items;
          _totalResults = res.pagination.total;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
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
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppInput(
                            controller: _controller,
                            placeholder: 'Search events, people, tags...',
                            icon: const Icon(LucideIcons.search, size: 20),
                            height: 48,
                            borderRadius: 50,
                            onChanged: (value) {
                              // handled by listener
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            LucideIcons.slidersHorizontal,
                            size: 24,
                            color: AppColors.primary,
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
                                setState(() => _activeFilter = f);
                                if (_controller.text.trim().length >= 2) {
                                  _search(_controller.text.trim());
                                }
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
                    : _suggestions.isNotEmpty && !_hasSearched
                    ? _buildSuggestions()
                    : _hasSearched
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
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
            _search(suggestion);
          },
        );
      },
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 48,
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
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalResults result${_totalResults != 1 ? 's' : ''} found',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(ExploreScreen.routePath),
                  child: const Text(
                    'Map View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._results.map((result) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  if (result.type == 'event') {
                    context.go(
                      EventDetailScreen.routePath.replaceAll(':id', result.id),
                    );
                  }
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
    return AppCard(
      padding: AppCardPadding.none,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      result.type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
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
                      result.description!,
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

  Widget _placeholderImage(SearchResult result) {
    return Container(
      width: 96,
      height: 96,
      color: AppColors.muted,
      child: Icon(
        result.type == 'event'
            ? LucideIcons.calendar
            : result.type == 'user'
            ? LucideIcons.user
            : LucideIcons.tag,
        size: 32,
        color: AppColors.mutedForeground,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.search, size: 48, color: AppColors.mutedForeground),
          SizedBox(height: 16),
          Text(
            'Search for events, people, or tags',
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
    );
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
