import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../profile/models/update.dart';
import '../../events/services/activity.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_pull_to_refresh.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../events/screens/event_detail.dart';
import '../../chat/screens/thread.dart';
import '../../profile/screens/profile_badges.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  static const String routePath = '/updates';

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

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
  }

  @override
  void dispose() {
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
          color: AppColors.primary,
        );
      case 'event.joined':
        return (
          icon: LucideIcons.users,
          title: 'Someone joined your event',
          body: 'A participant joined your event.',
          color: AppColors.accent,
        );
      case 'achievement.unlocked':
        return (
          icon: LucideIcons.award,
          title: 'Achievement unlocked!',
          body:
              update.payload['title']?.toString() ??
              'You unlocked a new achievement.',
          color: AppColors.warning,
        );
      case 'event.created':
        return (
          icon: LucideIcons.mapPin,
          title: update.payload['eventName']?.toString() ?? 'New event',
          body: 'Your event is now live.',
          color: AppColors.primary,
        );
      case 'event.verified':
        return (
          icon: LucideIcons.checkCircle2,
          title: 'Attendance verified',
          body: 'Your attendance has been confirmed.',
          color: AppColors.accent,
        );
      default:
        return (
          icon: LucideIcons.bell,
          title: update.type,
          body: 'You have a new update.',
          color: AppColors.mutedForeground,
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
    final typography = context.appTypography;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: typography.overline),
    );
  }

  Widget _notif(AppUpdate update) {
    final content = _contentFor(update);
    final typography = context.appTypography;

    return GestureDetector(
      onTap: () => _openUpdate(update),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: update.isUnread
              ? AppColors.muted.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: update.isUnread ? AppColors.primary : AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                content.icon,
                size: AppIconSizes.defaultSize,
                color: update.isUnread ? AppColors.surface : AppColors.primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          content.title,
                          style:
                              (update.isUnread
                                      ? typography.labelMD
                                      : typography.labelMDSemi)
                                  .copyWith(
                                    color: update.isUnread
                                        ? AppColors.primary
                                        : AppColors.mutedForeground,
                                  ),
                        ),
                      ),
                      if (update.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.body,
                    style: typography.bodyBase.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(update.createdAt),
                    style: typography.captionSM.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
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
        if (_updates.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: unreadCount > 0 ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                unreadCount > 0
                    ? '$unreadCount UNREAD'
                    : 'You are all caught up.',
                style: unreadCount > 0
                    ? context.appTypography.labelSM.copyWith(
                        color: AppColors.surface,
                      )
                    : context.appTypography.bodySM.copyWith(
                        color: AppColors.mutedForeground,
                      ),
              ),
            ),
          ),
        if (_updates.isNotEmpty) const SizedBox(height: 24),
        if (today.isNotEmpty) ...[
          _sectionLabel('TODAY'),
          const SizedBox(height: 12),
          ...today.map(_notif),
          const SizedBox(height: 20),
        ],
        if (earlier.isNotEmpty) ...[
          _sectionLabel('EARLIER'),
          const SizedBox(height: 12),
          ...earlier.map(_notif),
        ],
        if (_updates.isEmpty)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Text(
                'No updates yet.',
                style: context.appTypography.bodyMD.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        if (_isFetchingMore)
          const Padding(
            padding: EdgeInsets.only(top: 8),
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
          ),
        if (_updates.isNotEmpty && !_hasNext)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'You are all caught up.',
                style: context.appTypography.bodySM.copyWith(
                  color: AppColors.mutedForeground,
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
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const AppSkeletonLine(width: 88, height: 12),
          ),
        ),
        const SizedBox(height: 24),
        const AppSkeletonLine(width: 52, height: 12),
        const SizedBox(height: 12),
        ...List.generate(4, (_) => _buildUpdateSkeletonCard()),
      ],
    );
  }

  Widget _buildUpdateSkeletonCard() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 44, height: 44, shape: BoxShape.circle),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLine(width: 160, height: 16),
                    SizedBox(height: 10),
                    AppSkeletonLine(height: 12),
                    SizedBox(height: 8),
                    AppSkeletonLine(width: 96, height: 10),
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
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                title: 'Updates',
                showBack: false,
                rightElement: GestureDetector(
                  onTap: _updates.isEmpty || _isMarkingAll
                      ? null
                      : _markAllRead,
                  child: Text(
                    _isMarkingAll ? 'Marking...' : 'Mark all as read',
                    style: typography.bodySM.copyWith(
                      color: _updates.isEmpty || _isMarkingAll
                          ? AppColors.mutedForeground
                          : AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
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
