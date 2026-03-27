import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/header.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/media_preview.dart';
import 'package:intl/intl.dart';
import 'settings.dart';
import 'media_preview_screen.dart';
import '../models/achievement.dart';
import '../models/update.dart';
import '../models/user.dart';
import '../models/save.dart';
import '../providers/profile_overview.dart';
import '../providers/user.dart';
import '../services/save.dart';
import '../services/user.dart';
import '../utils/error.dart';
import '../widgets/app_pull_to_refresh.dart';
import '../widgets/snackbar.dart';
import 'profile_badges.dart';
import 'my_events.dart';
import 'updates.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  static const String routePath = '/profile';
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<User?>? _viewedUserFuture;
  SavedEntitySummary? _saveSummary;
  String? _saveStateUserId;
  bool _isLoadingSaveState = false;
  bool _isTogglingSave = false;

  bool get _isViewingOwnProfile => widget.userId == null;

  void _ensureViewedUser() {
    if (_isViewingOwnProfile || _viewedUserFuture != null) return;
    _viewedUserFuture = userService.getUserById(widget.userId!);
  }

  Future<void> _refreshOverview(String userId) async {
    ref.invalidate(profileOverviewProvider(userId));
    await ref.read(profileOverviewProvider(userId).future);
  }

  void _ensureSaveState(User viewedUser) {
    final currentUser = ref.read(userProfileProvider).value;
    final shouldShowSave =
        !_isViewingOwnProfile &&
        currentUser != null &&
        currentUser.id != viewedUser.id;

    if (!shouldShowSave || _isLoadingSaveState) {
      return;
    }

    if (_saveStateUserId == viewedUser.id && _saveSummary != null) {
      return;
    }

    _saveStateUserId = viewedUser.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSaveState(viewedUser.id, currentUser.id);
    });
  }

  Future<void> _loadSaveState(String viewedUserId, String currentUserId) async {
    if (viewedUserId == currentUserId) {
      if (!mounted) return;
      setState(() {
        _saveSummary = null;
        _isLoadingSaveState = false;
      });
      return;
    }

    setState(() => _isLoadingSaveState = true);
    try {
      final summary = await saveService.getSaveState('user', viewedUserId);
      if (!mounted || _saveStateUserId != viewedUserId) return;
      setState(() {
        _saveSummary = summary;
        _isLoadingSaveState = false;
      });
    } catch (_) {
      if (!mounted || _saveStateUserId != viewedUserId) return;
      setState(() => _isLoadingSaveState = false);
    }
  }

  Future<void> _toggleSaveProfile(User viewedUser) async {
    if (_isTogglingSave) return;
    final currentUser = ref.read(userProfileProvider).value;
    if (currentUser == null || currentUser.id == viewedUser.id) {
      return;
    }

    setState(() => _isTogglingSave = true);
    try {
      final summary = _saveSummary?.saved == true
          ? await saveService.unsaveEntity('user', viewedUser.id)
          : await saveService.saveEntity('user', viewedUser.id);
      if (!mounted) return;
      setState(() {
        _saveSummary = summary;
        _isTogglingSave = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingSave = false);
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
    }
  }

  Widget _profileHeaderAction(User viewedUser, {required bool showSelfActions}) {
    if (showSelfActions) {
      return GestureDetector(
        onTap: () => context.go(SettingsScreen.routePath),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            LucideIcons.settings,
            size: AppIconSizes.defaultSize,
            color: AppColors.primary,
          ),
        ),
      );
    }

    final currentUser = ref.watch(userProfileProvider).value;
    final canSave = currentUser != null && currentUser.id != viewedUser.id;
    if (!canSave) {
      return const SizedBox(width: 40);
    }

    _ensureSaveState(viewedUser);
    return GestureDetector(
      onTap: _isLoadingSaveState || _isTogglingSave
          ? null
          : () => _toggleSaveProfile(viewedUser),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: _isLoadingSaveState || _isTogglingSave
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                _saveSummary?.saved == true
                    ? LucideIcons.heartOff
                    : LucideIcons.heart,
                size: AppIconSizes.defaultSize,
                color: AppColors.primary,
              ),
      ),
    );
  }

  Future<void> _viewPhoto() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    Navigator.pop(context);
    await context.push(
      MediaPreviewScreen.routePath,
      extra: [
        MediaItem(
          id: user.id,
          url:
              user.avatarUrl ?? 'https://picsum.photos/seed/${user.id}/600/600',
          thumbnail:
              user.avatarUrl ?? 'https://picsum.photos/seed/${user.id}/120/120',
          type: 'image',
          name: user.name ?? 'Profile Photo',
        ),
      ],
    );
  }

  Future<void> _changePhoto() async {
    Navigator.pop(context);
    try {
      await ref.read(userProfileProvider.notifier).updateAvatar();
    } catch (_) {}
  }

  Future<void> _removePhoto() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text(
          'This will remove your current profile photo from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(userProfileProvider.notifier).updateUserData({
        'mediaId': null,
      });
    } catch (_) {}
  }

  void _showEditPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
            _sheetItem(
              label: 'View Photo',
              icon: LucideIcons.eye,
              onTap: _viewPhoto,
            ),
            _sheetItem(
              label: 'Change Photo',
              icon: LucideIcons.image,
              onTap: _changePhoto,
            ),
            _sheetItem(
              label: 'Remove Photo',
              icon: LucideIcons.trash2,
              isDestructive: true,
              onTap: _removePhoto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.05)
              : AppColors.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDestructive ? AppColors.error : AppColors.primary,
              ),
            ),
            Icon(
              icon,
              size: AppIconSizes.defaultSize,
              color: isDestructive ? AppColors.error : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    _ensureViewedUser();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          (_isViewingOwnProfile
                  ? userAsync.whenData((value) => value)
                  : const AsyncValue<User?>.data(null))
              .when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, _) => const Center(child: Text('User not found')),
                data: (currentUser) {
                  if (_isViewingOwnProfile) {
                    if (currentUser == null) {
                      return const Center(child: Text('User not found'));
                    }
                    return _buildProfileScaffold(
                      context,
                      currentUser,
                      showSelfActions: true,
                    );
                  }

                  return FutureBuilder<User?>(
                    future: _viewedUserFuture,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      final user = userSnapshot.data;
                      if (user == null) {
                        return const Center(child: Text('User not found'));
                      }
                      return _buildProfileScaffold(
                        context,
                        user,
                        showSelfActions: false,
                      );
                    },
                  );
                },
              ),
          if (_isViewingOwnProfile) const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildProfileScaffold(
    BuildContext context,
    User user, {
    required bool showSelfActions,
  }) {
    final overviewAsync = ref.watch(profileOverviewProvider(user.id));
    final overview = overviewAsync.value;

    return Column(
      children: [
        AppHeader(
          title: 'Profile',
          showBack: !showSelfActions,
          rightElement: _profileHeaderAction(
            user,
            showSelfActions: showSelfActions,
          ),
        ),
        Expanded(
          child: AppPullToRefresh(
            onRefresh: () => _refreshOverview(user.id),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
            child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: showSelfActions
                          ? () => _showEditPhotoOptions(context)
                          : null,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.border,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  AppColors.mutedForeground,
                                  BlendMode.saturation,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      user.avatarUrl ??
                                      'https://picsum.photos/seed/${user.id}/200/200',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          if (showSelfActions)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                size: AppIconSizes.s,
                                color: AppColors.surface,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name ?? 'Anonymous',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'PROFILE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: AppIconSizes.s,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'MEMBER SINCE ${DateFormat('MMM yyyy').format(user.createdAt ?? DateTime.now()).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Stats
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat('Events', '${overview?.myEvents.length ?? 0}'),
                          Container(
                            width: 1,
                            height: 48,
                            color: AppColors.border,
                          ),
                          _stat('Impact', '4.8k'),
                          Container(
                            width: 1,
                            height: 48,
                            color: AppColors.border,
                          ),
                          _stat('Rating', '4.9'),
                        ],
                      ),
                    ),
                    if (overviewAsync.isLoading && overview == null) ...[
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Badges',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showSelfActions)
                          GestureDetector(
                            onTap: () =>
                                context.go(ProfileBadgesScreen.routePath),
                            child: const Text(
                              'View All',
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
                    const SizedBox(height: 16),
                    Row(
                      children: _buildBadgeRow(
                        overview?.achievements ?? const [],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (showSelfActions) ...[
                      AppButton(
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => context.push(MyEventsScreen.routePath),
                        icon: const Icon(
                          LucideIcons.calendar,
                          color: AppColors.primary,
                          size: AppIconSizes.defaultSize,
                        ),
                        label: 'Manage My Events',
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Recent activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showSelfActions)
                          GestureDetector(
                            onTap: () => context.go(UpdatesScreen.routePath),
                            child: const Text(
                              'View All',
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
                    const SizedBox(height: 16),
                    ..._buildRecentActivity(
                      overview?.recentActivity ?? const [],
                    ),
                    const SizedBox(height: 32),

                    // Impact
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Impact Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final heights = [
                            40.0,
                            64.0,
                            48.0,
                            80.0,
                            56.0,
                            72.0,
                            96.0,
                          ];
                          final days = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: heights[i],
                                decoration: BoxDecoration(
                                  color: i == 6
                                      ? AppColors.primary
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                days[i],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      spacing: 4,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          spacing: 8,
          children: [
            Icon(icon, size: AppIconSizes.l, color: AppColors.primary),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBadgeRow(List<Achievement> achievements) {
    final items = achievements.take(4).toList();
    if (items.isEmpty) {
      return [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No badges unlocked yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final badge = items[i];
      widgets.add(
        _badge(_splitBadgeLabel(badge.title), _iconForAchievement(badge.icon)),
      );
      if (i != items.length - 1) {
        widgets.add(const SizedBox(width: 12));
      }
    }
    return widgets;
  }

  List<Widget> _buildRecentActivity(List<AppUpdate> updates) {
    if (updates.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'No recent activity yet.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < updates.length; i++) {
      final content = _contentFor(updates[i]);
      widgets.add(
        _activityItem(
          content.icon,
          content.title,
          _timeAgo(updates[i].createdAt),
          content.body,
        ),
      );
      if (i != updates.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }

  ({IconData icon, String title, String body}) _contentFor(AppUpdate update) {
    switch (update.type) {
      case 'event.created':
        return (
          icon: LucideIcons.mapPin,
          title: update.payload['eventName']?.toString() ?? 'Created an event',
          body: 'Your event is now live.',
        );
      case 'event.joined':
        return (
          icon: LucideIcons.users,
          title: 'Joined an event',
          body:
              update.payload['eventName']?.toString() ?? 'You joined an event.',
        );
      case 'event.left':
        return (
          icon: LucideIcons.userMinus,
          title: 'Left an event',
          body: update.payload['eventName']?.toString() ?? 'You left an event.',
        );
      case 'event.verified':
        return (
          icon: LucideIcons.checkCircle2,
          title: 'Attendance verified',
          body: 'Your attendance has been confirmed.',
        );
      case 'message.created':
        return (
          icon: LucideIcons.messageCircle,
          title: 'Posted a message',
          body:
              update.payload['message']?.toString() ??
              'You added to the conversation.',
        );
      case 'reaction.created':
        return (
          icon: LucideIcons.heart,
          title: 'Added a reaction',
          body:
              update.payload['emoji']?.toString() ?? 'You reacted to activity.',
        );
      case 'achievement.unlocked':
        return (
          icon: LucideIcons.award,
          title: update.payload['title']?.toString() ?? 'Achievement unlocked',
          body:
              update.payload['description']?.toString() ??
              'You unlocked a new badge.',
        );
      default:
        return (
          icon: LucideIcons.bell,
          title: update.type.replaceAll('.', ' '),
          body: 'You have recent activity.',
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

  String _splitBadgeLabel(String title) {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return title;
    final midpoint = (words.length / 2).ceil();
    return '${words.take(midpoint).join(' ')}\n${words.skip(midpoint).join(' ')}';
  }

  IconData _iconForAchievement(String? icon) {
    switch (icon) {
      case 'calendar':
        return LucideIcons.calendarDays;
      case 'message-circle':
        return LucideIcons.messageCircle;
      case 'heart':
        return LucideIcons.heart;
      case 'flame':
        return LucideIcons.flame;
      default:
        return LucideIcons.award;
    }
  }

  Widget _activityItem(
    IconData icon,
    String title,
    String time,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        spacing: 16,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppIconSizes.defaultSize,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
