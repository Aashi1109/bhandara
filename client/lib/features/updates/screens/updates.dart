import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../profile/models/update.dart';
import '../../events/services/activity.dart';
import '../../../shared/constants/socket_events.dart';
import '../../../shared/providers/notification_count.dart';
import '../../../shared/services/socket.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_pull_to_refresh.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../events/screens/event_detail.dart';
import '../../chat/screens/thread.dart';
import '../../profile/screens/profile_badges.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  static const String routePath = '/updates';

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _isMarkingAll = false;
  bool _hasNext = true;
  String? _nextCursor;
  List<AppUpdate> _updates = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUpdates(refresh: true);

    // Reset unread badge when updates screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unreadNotificationCountProvider.notifier).clear();
    });

    // Listen for real-time activity:new events and prepend to list.
    _socketSubscription = socketService.messages.listen((event) {
      if (event['event'] != SocketEvents.activityNew) return;
      final data = event['data'];
      if (data is! Map<String, dynamic>) return;
      final update = AppUpdate.fromJson(data);
      if (!mounted) return;
      setState(() => _updates = [update, ..._updates]);
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
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
      _loadUpdates();
    }
  }

  Future<void> _loadUpdates({bool refresh = false}) async {
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
      final response = await activityService.getMyUpdates(
        limit: _pageSize,
        next: refresh ? null : _nextCursor,
      );
      if (!mounted) return;

      final merged = <String, AppUpdate>{
        for (final update in refresh ? <AppUpdate>[] : _updates)
          update.id: update,
        for (final update in response.items) update.id: update,
      }.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _updates = merged;
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

  Future<void> _markAllRead() async {
    setState(() => _isMarkingAll = true);
    ref.read(unreadNotificationCountProvider.notifier).clear();
    try {
      await activityService.markAllRead();
      if (!mounted) return;
      setState(() {
        _updates = _updates
            .map(
              (update) => AppUpdate(
                id: update.id,
                type: update.type,
                entityType: update.entityType,
                entityId: update.entityId,
                payload: update.payload,
                createdAt: update.createdAt,
                readAt: DateTime.now(),
              ),
            )
            .toList();
      });
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  Future<void> _openUpdate(AppUpdate update) async {
    if (update.isUnread) {
      try {
        final updated = await activityService.markRead(update.id);
        if (mounted) {
          setState(() {
            _updates = _updates
                .map((item) => item.id == update.id ? updated : item)
                .toList();
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (update.entityType == 'event') {
      final eventId = (update.payload['eventId'] ?? update.entityId).toString();
      unawaited(
        context.push(EventDetailScreen.routePath.replaceAll(':id', eventId)),
      );
      return;
    }

    if (update.entityType == 'message') {
      final threadId = update.payload['threadId']?.toString();
      final messageId = update.payload['messageId']?.toString();
      if (threadId != null &&
          threadId.isNotEmpty &&
          messageId != null &&
          messageId.isNotEmpty) {
        unawaited(
          context.push(
            ThreadScreen.routePath.replaceAll(':id', messageId),
            extra: {'threadId': threadId, 'chatId': threadId},
          ),
        );
      }
      return;
    }

    if (update.entityType == 'achievement') {
      unawaited(context.push(ProfileBadgesScreen.routePath));
    }
  }

  ({IconData icon, String title, String body, Color color}) _contentFor(
    AppUpdate update,
  ) {
    switch (update.type) {
      case 'message.created':
        return (
          icon: LucideIcons.messageSquare,
          title: 'New message',
          body:
              update.payload['preview']?.toString() ??
              'Someone added a new message to a discussion.',
          color: context.appPalette.primary,
        );
      case 'event.joined':
        return (
          icon: LucideIcons.users,
          title: 'Someone joined your event',
          body: 'A participant joined your event.',
          color: context.appPalette.accent,
        );
      case 'achievement.unlocked':
        return (
          icon: LucideIcons.award,
          title: 'Achievement unlocked!',
          body:
              update.payload['title']?.toString() ??
              'You unlocked a new achievement.',
          color: context.appPalette.warning,
        );
      case 'event.created':
        return (
          icon: LucideIcons.mapPin,
          title: update.payload['eventName']?.toString() ?? 'New event',
          body: 'Your event is now live.',
          color: context.appPalette.primary,
        );
      case 'event.verified':
        return (
          icon: LucideIcons.checkCircle2,
          title: 'Attendance verified',
          body: 'Your attendance has been confirmed.',
          color: context.appPalette.accent,
        );
      default:
        return (
          icon: LucideIcons.bell,
          title: update.type,
          body: 'You have a new update.',
          color: context.appPalette.mutedForeground,
        );
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: context.appTypography.overline.copyWith(
        color: context.appPalette.mutedForeground,
        letterSpacing: 1,
      ),
    );
  }

  Widget _unreadSummary(int unreadCount) {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appPalette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.bellRing,
              size: AppIconSizes.defaultSize,
              color: context.appPalette.accent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  'You have $unreadCount new ${unreadCount == 1 ? 'update' : 'updates'}',
                  style: typography.titleXSStrong.copyWith(
                    color: context.appPalette.primary,
                  ),
                ),
                Text(
                  'Here’s what happened while you were away',
                  style: typography.bodyXS.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appPalette.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$unreadCount',
              style: typography.bodySMExtraBold.copyWith(
                color: context.appPalette.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notif(AppUpdate update) {
    final content = _contentFor(update);
    final typography = context.appTypography;

    return InkWell(
      onTap: () => _openUpdate(update),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appPalette.border)),
        ),
        child: Row(
          spacing: 12,
          children: [
            if (update.isUnread)
              Container(
                width: 3,
                height: 44,
                decoration: BoxDecoration(
                  color: context.appPalette.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appPalette.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                content.icon,
                size: AppIconSizes.defaultSize,
                color: content.color,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.labelMD.copyWith(
                            color: context.appPalette.primary,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(update.createdAt),
                        style: typography.captionSMStrong.copyWith(
                          color: context.appPalette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    content.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.bodySM.copyWith(
                      color: context.appPalette.mutedForeground,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (update.isUnread)
              SizedBox(
                width: 7,
                height: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.appPalette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesList() {
    final unreadCount = _updates.where((update) => update.isUnread).length;
    final now = DateTime.now();
    final today = _updates.where((update) {
      return update.createdAt.year == now.year &&
          update.createdAt.month == now.month &&
          update.createdAt.day == now.day;
    }).toList();
    final earlier = _updates
        .where((update) => !today.contains(update))
        .toList();

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      children: [
        if (_updates.isNotEmpty && unreadCount > 0) ...[
          _unreadSummary(unreadCount),
          const SizedBox(height: 16),
        ],
        if (today.isNotEmpty) ...[
          _sectionLabel(
            'TODAY · ${DateFormat('MMM d').format(now).toUpperCase()}',
          ),
          const SizedBox(height: 4),
          ...today.map(_notif),
          const SizedBox(height: 16),
        ],
        if (earlier.isNotEmpty) ...[
          _sectionLabel('EARLIER THIS WEEK'),
          const SizedBox(height: 4),
          ...earlier.map(_notif),
        ],
        if (_updates.isEmpty)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Text(
                'No updates yet.',
                style: context.appTypography.bodyMD.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
              ),
            ),
          ),
        if (_isFetchingMore)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: AppSkeletonLine(width: 80, height: 8)),
          ),
        if (_updates.isNotEmpty && !_hasNext)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'You are all caught up.',
                style: context.appTypography.bodySM.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      children: [
        Container(
          height: 80,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appPalette.muted,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            spacing: 12,
            children: [
              AppSkeleton(width: 44, height: 44, shape: BoxShape.circle),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    AppSkeletonLine(width: 150, height: 12),
                    AppSkeletonLine(width: 210, height: 9),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppSkeletonLine(width: 92, height: 10),
        const SizedBox(height: 4),
        ...List.generate(5, (_) => _buildUpdateSkeletonCard()),
      ],
    );
  }

  Widget _buildUpdateSkeletonCard() {
    return SizedBox(
      height: 78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appPalette.border)),
        ),
        child: const Row(
          spacing: 12,
          children: [
            AppSkeleton(width: 44, height: 44, shape: BoxShape.circle),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  AppSkeletonLine(width: 160, height: 12),
                  AppSkeletonLine(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final unreadCount = _updates.where((update) => update.isUnread).length;
    final showCaughtUpInHeader = _updates.isNotEmpty && unreadCount == 0;

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                title: 'Updates',
                showBack: false,
                rightElement: GestureDetector(
                  onTap:
                      _updates.isEmpty || _isMarkingAll || showCaughtUpInHeader
                      ? null
                      : _markAllRead,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Icon(
                        LucideIcons.checkCheck,
                        size: AppIconSizes.s,
                        color: _updates.isEmpty || showCaughtUpInHeader
                            ? context.appPalette.mutedForeground
                            : context.appPalette.accent,
                      ),
                      Text(
                        _isMarkingAll
                            ? 'Marking…'
                            : showCaughtUpInHeader
                            ? 'Caught up'
                            : 'Mark all read',
                        style: typography.bodySMStrong.copyWith(
                          color: _updates.isEmpty || showCaughtUpInHeader
                              ? context.appPalette.mutedForeground
                              : context.appPalette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : AppPullToRefresh(
                        onRefresh: () => _loadUpdates(refresh: true),
                        wrapInScrollView: false,
                        child: _buildUpdatesList(),
                      ),
              ),
            ],
          ),
          const AppBottomNav(),
        ],
      ),
    );
  }
}
