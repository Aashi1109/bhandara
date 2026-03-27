import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../services/event.dart';
import '../services/user.dart';
import '../theme/theme.dart';
import '../widgets/app_pull_to_refresh.dart';
import '../widgets/button.dart';
import '../widgets/header.dart';
import 'create_event.dart';
import 'event_detail.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  static const String routePath = '/profile/my-events';

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasNext = true;
  String? _nextCursor;
  String? _currentUserId;
  List<Event> _events = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadEvents(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || _isFetchingMore || !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 320) {
      _loadEvents();
    }
  }

  Future<List<Event>> _hydrateEvents(List<Event> events) async {
    final hydrated = await Future.wait(
      events.map((event) async {
        try {
          return await eventService.getEventPreview(event.id);
        } catch (_) {
          return event;
        }
      }),
    );

    hydrated.sort((a, b) => b.startTime.compareTo(a.startTime));
    return hydrated;
  }

  Future<void> _loadEvents({bool refresh = false}) async {
    if ((_isLoading && !refresh) || _isFetchingMore) return;

    if (refresh) {
      setState(() {
        _isLoading = true;
        _isFetchingMore = false;
        _nextCursor = null;
        _hasNext = true;
      });
    } else {
      if (!_hasNext) return;
      setState(() => _isFetchingMore = true);
    }

    try {
      final userId =
          _currentUserId ?? (await userService.getCurrentUser())?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _events = const [];
          _isLoading = false;
          _isFetchingMore = false;
          _hasNext = false;
        });
        return;
      }
      _currentUserId = userId;

      final response = await eventService.getEvents(
        createdBy: userId,
        limit: _pageSize,
        next: refresh ? null : _nextCursor,
      );
      final pageEvents = await _hydrateEvents(response.items);

      if (!mounted) return;

      final merged = <String, Event>{
        for (final event in refresh ? <Event>[] : _events) event.id: event,
        for (final event in pageEvents) event.id: event,
      }.values.toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      setState(() {
        _events = merged;
        _nextCursor = response.pagination.next;
        _hasNext = response.pagination.hasNext;
        _isLoading = false;
        _isFetchingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  Widget _buildEventCard(Event event) {
    return GestureDetector(
      onTap: () => context.go(
        EventDetailScreen.routePath.replaceAll(':id', event.id),
        extra: event,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEE, d MMM • h:mm a').format(event.startTime),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.location.address,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _engagementMeta(
                  LucideIcons.eye,
                  '${event.stats?.viewCount ?? 0} views',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _engagementMeta(
                    LucideIcons.star,
                    event.stats != null && event.stats!.ratingCount > 0
                        ? '${event.stats!.ratingAverage.toStringAsFixed(1)} (${event.stats!.ratingCount})'
                        : 'No ratings',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          LucideIcons.calendarDays,
          size: AppIconSizes.hero,
          color: AppColors.mutedForeground,
        ),
        const SizedBox(height: 16),
        const Text(
          'You have not created any events yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Create Event',
          size: AppButtonSize.lg,
          onPressed: () => context.go(CreateEventScreen.routePath),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_isFetchingMore) {
      return const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 12),
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

    if (_events.isNotEmpty && !_hasNext) {
      return const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 12),
        child: Center(
          child: Text(
            'You are all caught up.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Manage My Events'),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : AppPullToRefresh(
                    onRefresh: () => _loadEvents(refresh: true),
                    wrapInScrollView: false,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      itemCount: _events.isEmpty ? 1 : _events.length + 1,
                      itemBuilder: (context, index) {
                        if (_events.isEmpty) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.55,
                            child: _buildEmptyState(),
                          );
                        }

                        if (index == _events.length) {
                          return _buildFooter();
                        }

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _events.length - 1 ? 0 : 12,
                          ),
                          child: _buildEventCard(_events[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _engagementMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Icon(icon, size: AppIconSizes.s, color: AppColors.mutedForeground),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
