import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/update.dart';
import '../services/activity.dart';
import '../theme/theme.dart';
import '../widgets/app_pull_to_refresh.dart';
import '../widgets/header.dart';
import '../widgets/bottom_nav.dart';
import 'event_detail.dart';
import 'thread.dart';
import 'profile_badges.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  static const String routePath = '/updates';

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _isLoading = true;
  bool _isMarkingAll = false;
  List<AppUpdate> _updates = const [];

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    setState(() => _isLoading = true);
    try {
      final response = await activityService.getMyUpdates(limit: 50);
      if (!mounted) return;
      setState(() {
        _updates = response.items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
      context.go(EventDetailScreen.routePath.replaceAll(':id', eventId));
      return;
    }

    if (update.entityType == 'message') {
      final threadId = update.payload['threadId']?.toString();
      final messageId = update.payload['messageId']?.toString();
      if (threadId != null &&
          threadId.isNotEmpty &&
          messageId != null &&
          messageId.isNotEmpty) {
        context.go(
          ThreadScreen.routePath.replaceAll(':id', messageId),
          extra: {'threadId': threadId, 'chatId': threadId},
        );
      }
      return;
    }

    if (update.entityType == 'achievement') {
      context.go(ProfileBadgesScreen.routePath);
      return;
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
          body: 'Someone added a new message to a discussion.',
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

  @override
  Widget build(BuildContext context) {
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : AppPullToRefresh(
                        onRefresh: _loadUpdates,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                '$unreadCount UNREAD',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: AppColors.surface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (today.isNotEmpty) ...[
                              _sectionLabel('TODAY'),
                              const SizedBox(height: 12),
                              ...today.map(_notif),
                              const SizedBox(height: 32),
                            ],
                            if (earlier.isNotEmpty) ...[
                              _sectionLabel('EARLIER'),
                              const SizedBox(height: 12),
                              ...earlier.map(_notif),
                            ],
                            if (_updates.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 32),
                                child: Center(
                                  child: Text(
                                    'No updates yet.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _notif(AppUpdate update) {
    final content = _contentFor(update);

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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: update.isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(update.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
}
