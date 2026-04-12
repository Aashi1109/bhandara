import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/constants/socket_events.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../events/widgets/media_preview.dart';
import 'package:intl/intl.dart';
import '../../settings/screens/settings.dart';
import '../models/achievement.dart';
import '../models/update.dart';
import '../models/user.dart';
import '../../saved/models/save.dart';
import '../providers/profile_overview.dart';
import '../../../shared/providers/user.dart';
import '../../saved/services/save.dart';
import '../../../shared/services/socket.dart';
import '../services/user.dart';
import '../../../shared/utils/error.dart';
import '../../../shared/widgets/app_pull_to_refresh.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/snackbar.dart';
import './profile_badges.dart';
import '../../events/screens/my_events.dart';
import '../../updates/screens/updates.dart';

typedef CurrentUserLoader = Future<User?> Function();

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId, this.currentUserLoader});

  static const String routePath = '/profile';
  final String? userId;
  final CurrentUserLoader? currentUserLoader;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileStatSkeleton extends StatelessWidget {
  const _ProfileStatSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppSkeletonLine(width: 52, height: 20),
        SizedBox(height: 8),
        AppSkeletonLine(width: 62, height: 12),
      ],
    );
  }
}

class _ProfileVerticalDividerSkeleton extends StatelessWidget {
  const _ProfileVerticalDividerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 48, color: AppColors.border);
  }
}

class _ProfileActivitySkeleton extends StatelessWidget {
  const _ProfileActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          AppSkeleton(width: 40, height: 40, shape: BoxShape.circle),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: AppSkeletonLine(width: 120, height: 14)),
                    SizedBox(width: 12),
                    AppSkeletonLine(width: 56, height: 10),
                  ],
                ),
                SizedBox(height: 8),
                AppSkeletonLine(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBadgeSkeleton extends StatelessWidget {
  const _ProfileBadgeSkeleton();

  @override
  Widget build(BuildContext context) {
    final skeletonBase = AppColors.border.withValues(alpha: 0.92);
    final skeletonHighlight = AppColors.surface.withValues(alpha: 0.98);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            AppSkeleton(
              width: 22,
              height: 22,
              shape: BoxShape.circle,
              baseColor: skeletonBase,
              highlightColor: skeletonHighlight,
            ),
            AppSkeletonLine(
              width: 48,
              height: 10,
              baseColor: skeletonBase,
              highlightColor: skeletonHighlight,
            ),
            AppSkeletonLine(
              width: 36,
              height: 10,
              baseColor: skeletonBase,
              highlightColor: skeletonHighlight,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<User?>? _currentUserFuture;
  User? _currentUserOverride;
  Future<User?>? _viewedUserFuture;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  SavedEntitySummary? _saveSummary;
  String? _saveStateUserId;
  bool _isLoadingSaveState = false;
  bool _isTogglingSave = false;
  User? _viewedUserOverride;

  bool get _isViewingOwnProfile => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _socketSubscription = socketService.messages.listen((event) {
      if (_isViewingOwnProfile) {
        return;
      }

      final eventName = event['event'];
      if (eventName != SocketEvents.userUpdate) {
        return;
      }

      final payload = event['data'];
      final userMap = payload is Map<String, dynamic>
          ? payload
          : payload is Map
          ? Map<String, dynamic>.from(payload)
          : null;
      if (userMap == null) {
        return;
      }

      final updatedUserId = userMap['id'] as String?;
      if (updatedUserId == null || updatedUserId != widget.userId) {
        return;
      }

      final updatedUser = User.fromJson(userMap);
      if (!mounted) {
        return;
      }

      setState(() {
        _viewedUserOverride = updatedUser;
        _viewedUserFuture = Future<User?>.value(updatedUser);
      });
    });
  }

  void _ensureViewedUser() {
    if (_isViewingOwnProfile || _viewedUserFuture != null) return;
    _viewedUserFuture = userService.getUserById(widget.userId!);
  }

  void _ensureCurrentUser(AsyncValue<User?> userAsync) {
    if (!_isViewingOwnProfile || _currentUserFuture != null) return;
    if (userAsync.isLoading || userAsync.hasError) return;

    final currentUser = userAsync.value;
    if (currentUser != null) {
      _currentUserOverride = currentUser;
      return;
    }

    _currentUserFuture = _loadCurrentUser();
  }

  Future<User?> _loadCurrentUser() async {
    final user = await (widget.currentUserLoader ?? userService.getCurrentUser)
        .call();
    if (!mounted || user == null) {
      return user;
    }

    setState(() {
      _currentUserOverride = user;
    });
    ref.read(userProfileProvider.notifier).setUser(user);
    return user;
  }

  Future<void> _refreshOverview(String userId) async {
    ref.invalidate(profileOverviewProvider(userId: userId));
    await ref.read(profileOverviewProvider(userId: userId).future);
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

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  Widget _profileHeaderAction(
    User viewedUser, {
    required bool showSelfActions,
  }) {
    if (showSelfActions) {
      return GestureDetector(
        onTap: () => context.push(SettingsScreen.routePath),
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

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile photo preview',
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => AppMediaPreview(
        items: [
          MediaItem(
            id: user.id,
            url:
                user.avatarUrl ??
                'https://picsum.photos/seed/${user.id}/600/600',
            thumbnail:
                user.avatarUrl ??
                'https://picsum.photos/seed/${user.id}/120/120',
            type: 'image',
            name: user.name ?? 'Profile Photo',
          ),
        ],
        onClose: () => Navigator.of(context).pop(),
      ),
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
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final typography = sheetContext.appTypography;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(sheetContext).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Profile Photo',
                      style: typography.titleLGStrong.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Manage how your profile photo appears across the app.',
                        style: typography.bodyBase.copyWith(
                          color: AppColors.mutedForeground,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetItem(
                  label: 'View Photo',
                  icon: LucideIcons.eye,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _viewPhoto();
                  },
                ),
                const SizedBox(height: 12),
                _sheetItem(
                  label: 'Change Photo',
                  icon: LucideIcons.image,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _changePhoto();
                  },
                ),
                const SizedBox(height: 12),
                _sheetItem(
                  label: 'Remove Photo',
                  icon: LucideIcons.trash2,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removePhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final typography = context.appTypography;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDestructive
                  ? AppColors.error.withValues(alpha: 0.18)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: AppIconSizes.defaultSize,
                  color: isDestructive ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: typography.titleXSStrong.copyWith(
                    color: isDestructive ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: AppIconSizes.defaultSize,
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.8)
                    : AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileLoadingScaffold({required bool showSelfActions}) {
    return Column(
      children: [
        AppHeader(
          title: 'Profile',
          showBack: !showSelfActions,
          rightElement: const AppSkeleton(
            width: 40,
            height: 40,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
            children: [
              const Center(
                child: AppSkeleton(
                  width: 96,
                  height: 96,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: AppSkeletonLine(width: 148, height: 20)),
              const SizedBox(height: 10),
              const Center(child: AppSkeletonLine(width: 72, height: 12)),
              const SizedBox(height: 8),
              const Center(child: AppSkeletonLine(width: 168, height: 12)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ProfileStatSkeleton(),
                    _ProfileVerticalDividerSkeleton(),
                    _ProfileStatSkeleton(),
                    _ProfileVerticalDividerSkeleton(),
                    _ProfileStatSkeleton(),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const AppSkeletonLine(width: 84, height: 18),
              const SizedBox(height: 16),
              const Row(
                children: [
                  _ProfileBadgeSkeleton(),
                  SizedBox(width: 12),
                  _ProfileBadgeSkeleton(),
                  SizedBox(width: 12),
                  _ProfileBadgeSkeleton(),
                ],
              ),
              if (showSelfActions) ...[
                const SizedBox(height: 32),
                const AppSkeleton(
                  height: 52,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
              const SizedBox(height: 32),
              const AppSkeletonLine(width: 118, height: 18),
              const SizedBox(height: 16),
              const _ProfileActivitySkeleton(),
              const SizedBox(height: 12),
              const _ProfileActivitySkeleton(),
              const SizedBox(height: 32),
              const AppSkeletonLine(width: 132, height: 18),
              const SizedBox(height: 16),
              const AppSkeleton(
                height: 180,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    _ensureCurrentUser(userAsync);
    _ensureViewedUser();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          (_isViewingOwnProfile
                  ? userAsync.whenData((value) => value)
                  : const AsyncValue<User?>.data(null))
              .when(
                loading: () => _buildProfileLoadingScaffold(
                  showSelfActions: _isViewingOwnProfile,
                ),
                error: (_, _) => const Center(child: Text('User not found')),
                data: (currentUser) {
                  if (_isViewingOwnProfile) {
                    final resolvedCurrentUser =
                        _currentUserOverride ?? currentUser;
                    if (resolvedCurrentUser != null) {
                      return _buildProfileScaffold(
                        context,
                        resolvedCurrentUser,
                        showSelfActions: true,
                      );
                    }

                    return FutureBuilder<User?>(
                      future: _currentUserFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildProfileLoadingScaffold(
                            showSelfActions: true,
                          );
                        }

                        final user = _currentUserOverride ?? snapshot.data;
                        if (user == null) {
                          return const Center(child: Text('User not found'));
                        }

                        return _buildProfileScaffold(
                          context,
                          user,
                          showSelfActions: true,
                        );
                      },
                    );
                  }

                  return FutureBuilder<User?>(
                    future: _viewedUserFuture,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _buildProfileLoadingScaffold(
                          showSelfActions: false,
                        );
                      }

                      final user = _viewedUserOverride ?? userSnapshot.data;
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
    final overviewAsync = ref.watch(profileOverviewProvider(userId: user.id));
    final overview = overviewAsync.value;
    final typography = context.appTypography;

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
                          border: Border.all(color: AppColors.border, width: 3),
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
                  style: typography.heading3Strong,
                ),
                const SizedBox(height: 6),
                Text('PROFILE', style: typography.overline),
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
                      style: typography.overline,
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
                  child: overviewAsync.isLoading && overview == null
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ProfileStatSkeleton(),
                            _ProfileVerticalDividerSkeleton(),
                            _ProfileStatSkeleton(),
                            _ProfileVerticalDividerSkeleton(),
                            _ProfileStatSkeleton(),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(
                              'Events',
                              '${overview?.myEvents.length ?? 0}',
                            ),
                            Container(
                              width: 1,
                              height: 48,
                              color: AppColors.border,
                            ),
                            _stat(
                              'Impact',
                              _formatCount(
                                (overview?.impactStats?['totalViews'] as num?)
                                        ?.toInt() ??
                                    0,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 48,
                              color: AppColors.border,
                            ),
                            _stat(
                              'Rating',
                              () {
                                final avg =
                                    (overview?.impactStats?['avgRating']
                                            as num?)
                                        ?.toDouble() ??
                                    0.0;
                                return avg > 0
                                    ? avg.toStringAsFixed(1)
                                    : '—';
                              }(),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 32),

                // Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Badges', style: typography.titleMD),
                    if (showSelfActions)
                      GestureDetector(
                        onTap: () =>
                            context.push(ProfileBadgesScreen.routePath),
                        child: Text(
                          'View All',
                          style: typography.bodySMStrong.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (overviewAsync.isLoading && overview == null)
                  const Row(
                    children: [
                      _ProfileBadgeSkeleton(),
                      SizedBox(width: 12),
                      _ProfileBadgeSkeleton(),
                      SizedBox(width: 12),
                      _ProfileBadgeSkeleton(),
                    ],
                  )
                else
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
                    Text('Recent Activity', style: typography.titleMD),
                    if (showSelfActions)
                      GestureDetector(
                        onTap: () => context.push(UpdatesScreen.routePath),
                        child: Text(
                          'View All',
                          style: typography.bodySMStrong.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (overviewAsync.isLoading && overview == null) ...const [
                  _ProfileActivitySkeleton(),
                  SizedBox(height: 12),
                  _ProfileActivitySkeleton(),
                ] else
                  ..._buildRecentActivity(overview?.recentActivity ?? const []),
                const SizedBox(height: 32),

                // Impact
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Impact Overview', style: typography.titleMD),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Builder(
                    builder: (context) {
                      final rawEvents =
                          (overview?.impactStats?['events'] as List?)
                              ?.whereType<Map>()
                              .map((e) => e.cast<String, dynamic>())
                              .toList() ??
                          [];
                      final graphEvents = rawEvents.take(7).toList();

                      if (graphEvents.isEmpty) {
                        return SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'No events yet',
                              style: typography.bodySM.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        );
                      }

                      const double graphHeight = 96.0;
                      const double minBarHeight = 32.0;

                      final maxViews = graphEvents.fold<int>(
                        0,
                        (m, e) =>
                            max(m, (e['viewCount'] as num?)?.toInt() ?? 0),
                      );

                      return SizedBox(
                        height: graphHeight + 28, // bars + label space
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: graphEvents.asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          final views =
                              (e['viewCount'] as num?)?.toInt() ?? 0;
                          final barHeight = maxViews == 0
                              ? minBarHeight
                              : minBarHeight +
                                  (views / maxViews) *
                                      (graphHeight - minBarHeight);
                          final isLast = i == graphEvents.length - 1;

                          String label = '';
                          final rawStart = e['startTime'];
                          if (rawStart != null) {
                            try {
                              final dt = DateTime.parse(rawStart.toString());
                              label = DateFormat('MMM d').format(dt);
                            } catch (_) {
                              label = '';
                            }
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isLast
                                      ? AppColors.primary
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                style: typography.labelSM.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _stat(String label, String value) {
    final typography = context.appTypography;
    return Column(
      spacing: 4,
      children: [
        Text(value, style: typography.heading3),
        Text(label.toUpperCase(), style: typography.overline),
      ],
    );
  }

  Widget _badge(String label, IconData icon) {
    final typography = context.appTypography;
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
            Text(label, textAlign: TextAlign.center, style: typography.labelSM),
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
            child: Text(
              'No badges unlocked yet.',
              textAlign: TextAlign.center,
              style: context.appTypography.bodySM.copyWith(
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
          child: Text(
            'No recent activity yet.',
            style: context.appTypography.bodySM.copyWith(
              color: AppColors.mutedForeground,
            ),
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
              update.payload['preview']?.toString() ??
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
    final typography = context.appTypography;
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
                    Text(title, style: typography.labelMD),
                    Text(
                      time,
                      style: typography.labelSM.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typography.bodySM.copyWith(
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
