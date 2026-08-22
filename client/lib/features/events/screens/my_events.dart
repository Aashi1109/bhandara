import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../services/event.dart';
import '../../profile/services/user.dart';
import '../../../shared/constants/app_image_urls.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_pull_to_refresh.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/snackbar.dart';
import '../widgets/event_empty_state.dart';
import '../widgets/manage_events_controls.dart';
import '../widgets/managed_event_card.dart';
import './create_event.dart';
import './event_attendees.dart';
import './event_detail.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({
    super.key,
    this.initialEvents,
    this.loadRemoteImages = true,
  });

  static const String routePath = '/profile/my-events';

  final List<Event>? initialEvents;
  final bool loadRemoteImages;

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  ManagedEventFilter _filter = ManagedEventFilter.upcoming;
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
    final initialEvents = widget.initialEvents;
    if (initialEvents != null) {
      _events = List<Event>.from(initialEvents);
      _isLoading = false;
      _hasNext = false;
    } else {
      _loadEvents(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<Event> get _visibleEvents => filterManagedEvents(_events, _filter);

  int get _activeAttendeeCount =>
      filterManagedEvents(_events, ManagedEventFilter.upcoming).fold(0, (
        total,
        event,
      ) {
        return total +
            (event.stats?.participantCount ?? event.participants?.length ?? 0);
      });

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isFetchingMore ||
        !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 320) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents({bool refresh = false}) async {
    if (widget.initialEvents != null) return;
    if ((_isLoading && !refresh) || _isFetchingMore) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
        _nextCursor = null;
        _hasNext = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final userId = _currentUserId ?? (await userService.getCurrentUser())?.id;
      if (userId == null) {
        _applyEmptyResponse();
        return;
      }
      _currentUserId = userId;
      final response = await eventService.getEvents(
        createdBy: userId,
        limit: _pageSize,
        next: refresh ? null : _nextCursor,
      );
      final hydrated = await Future.wait(
        response.items.map((event) async {
          try {
            return await eventService.getEventPreview(event.id);
          } catch (_) {
            return event;
          }
        }),
      );
      if (!mounted) return;

      final merged = <String, Event>{
        for (final event in refresh ? <Event>[] : _events) event.id: event,
        for (final event in hydrated) event.id: event,
      }.values.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));

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

  void _applyEmptyResponse() {
    if (!mounted) return;
    setState(() {
      _events = const [];
      _isLoading = false;
      _isFetchingMore = false;
      _hasNext = false;
    });
  }

  Future<void> _openCreateEvent() async {
    await context.push(CreateEventScreen.routePath);
    if (mounted) await _loadEvents(refresh: true);
  }

  Future<void> _openEditEvent(Event event) async {
    await context.push(CreateEventScreen.routePath, extra: event);
    if (mounted) await _loadEvents(refresh: true);
  }

  void _openAttendees(Event event) {
    context.push(
      EventAttendeesScreen.routePath,
      extra: {
        'eventName': event.name,
        'attendees': (event.participants ?? const [])
            .whereType<EventUser>()
            .toList(),
        'capacity': event.capacity,
      },
    );
  }

  void _duplicateEvent() {
    AppSnackBar.info(context, 'Event duplication is coming soon.');
  }

  void _confirmCancel(Event event) {
    showAppDialog(
      context: context,
      title: 'Cancel event?',
      message: 'Attendees will see that this event has been cancelled.',
      primaryLabel: 'Cancel event',
      secondaryLabel: 'Keep event',
      onPrimaryPressed: () => _cancelEvent(event),
    );
  }

  Future<void> _cancelEvent(Event event) async {
    try {
      await eventService.updateEvent(event.id, const {'status': 'cancelled'});
      if (!mounted) return;
      AppSnackBar.info(context, 'Event cancelled.');
      await _loadEvents(refresh: true);
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'Unable to cancel the event.');
    }
  }

  void _showActions(Event event) {
    showManagedEventActions(
      context: context,
      event: event,
      onEdit: () => _openEditEvent(event),
      onViewAttendees: () => _openAttendees(event),
      onDuplicate: _duplicateEvent,
      onCancel: () => _confirmCancel(event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Manage My Events',
            rightElement: _CreateEventButton(onTap: _openCreateEvent),
          ),
          Expanded(
            child: _isLoading
                ? const _ManagedEventsLoading()
                : AppPullToRefresh(
                    onRefresh: () => _loadEvents(refresh: true),
                    wrapInScrollView: false,
                    child: _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final events = _visibleEvents;
    return LayoutBuilder(
      builder: (context, constraints) {
        final remainingHeight = constraints.maxHeight - 214;
        final emptyStateHeight = remainingHeight > 430
            ? remainingHeight
            : 430.0;

        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            ManageEventsOverview(
              eventCount: events.length,
              attendeeCount: _activeAttendeeCount,
              filter: _filter,
              loadIllustration: widget.loadRemoteImages,
            ),
            const SizedBox(height: 16),
            ManageEventsFilters(
              value: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              SizedBox(
                key: const ValueKey('managed-events-empty-area'),
                height: emptyStateHeight,
                child: _buildEmptyState(),
              )
            else
              ...events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ManagedEventCard(
                    event: event,
                    onTap: () => context.push(
                      EventDetailScreen.routePath.replaceAll(':id', event.id),
                      extra: event,
                    ),
                    onActions: () => _showActions(event),
                  ),
                ),
              ),
            if (_isFetchingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: AppSkeletonLine(width: 80, height: 8)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return switch (_filter) {
      ManagedEventFilter.upcoming => EventEmptyState(
        imageUrl: AppImageUrls.emptyUpcomingEvents,
        imageSemanticsLabel: 'Host preparing an empty event table',
        fallbackIcon: LucideIcons.calendarPlus,
        title: 'Your next gathering starts here',
        description:
            'Create an event and we will keep the date, guest list, and details together.',
        actionLabel: 'Create an event',
        onAction: _openCreateEvent,
        loadIllustration: widget.loadRemoteImages,
      ),
      ManagedEventFilter.past => EventEmptyState(
        imageUrl: AppImageUrls.emptyPastEvents,
        imageSemanticsLabel: 'Friends remembering a shared meal',
        fallbackIcon: LucideIcons.history,
        title: 'No past events yet',
        description:
            'When an event wraps up, its story and details will live here.',
        loadIllustration: widget.loadRemoteImages,
      ),
      ManagedEventFilter.drafts => EventEmptyState(
        imageUrl: AppImageUrls.emptyDraftEvents,
        imageSemanticsLabel: 'Host planning an event at a table',
        fallbackIcon: LucideIcons.fileEdit,
        title: 'No drafts waiting',
        description:
            'Start an event and save your progress. Unpublished details will stay here until you are ready.',
        actionLabel: 'Create an event',
        onAction: _openCreateEvent,
        loadIllustration: widget.loadRemoteImages,
      ),
    };
  }
}

class _CreateEventButton extends StatelessWidget {
  const _CreateEventButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          LucideIcons.plus,
          size: AppIconSizes.defaultSize,
          color: AppColors.surface,
        ),
      ),
    );
  }
}

class _ManagedEventsLoading extends StatelessWidget {
  const _ManagedEventsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => const AppSkeleton(height: 146),
    );
  }
}
