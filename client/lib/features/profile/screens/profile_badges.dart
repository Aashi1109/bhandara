import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/providers/user.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/skeleton.dart';
import '../models/achievement.dart';
import '../services/user.dart';

class ProfileBadgesScreen extends ConsumerWidget {
  const ProfileBadgesScreen({super.key});

  static const String routePath = '/profile/badges';
  static const int _collectionSize = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Badges'),
          Expanded(
            child: userAsync.when(
              loading: () => _buildLoadingState(context),
              error: (_, _) => const _MessageState(
                icon: LucideIcons.alertCircle,
                message: 'Unable to load badges',
              ),
              data: (user) {
                if (user == null) {
                  return const _MessageState(
                    icon: LucideIcons.userX,
                    message: 'User not found',
                  );
                }

                return FutureBuilder<List<Achievement>>(
                  future: userService.getUserAchievements(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState(context);
                    }
                    if (snapshot.hasError) {
                      return const _MessageState(
                        icon: LucideIcons.alertCircle,
                        message: 'Unable to load badges',
                      );
                    }
                    return _BadgeCollection(
                      badges: snapshot.data ?? const <Achievement>[],
                      collectionSize: _collectionSize,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Container(
          height: 120,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.appPalette.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            spacing: 16,
            children: [
              AppSkeleton(width: 62, height: 62, shape: BoxShape.circle),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    AppSkeletonLine(width: 150, height: 16),
                    AppSkeletonLine(height: 7),
                    AppSkeletonLine(width: 180, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const AppSkeletonLine(width: 130, height: 18),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: context.appPalette.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                AppSkeleton(width: double.infinity, height: 76),
                AppSkeletonLine(width: 100, height: 12),
                AppSkeletonLine(height: 9),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeCollection extends StatelessWidget {
  const _BadgeCollection({required this.badges, required this.collectionSize});

  final List<Achievement> badges;
  final int collectionSize;

  @override
  Widget build(BuildContext context) {
    final earnedCount = badges.length > collectionSize
        ? collectionSize
        : badges.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _ProgressHero(earnedCount: earnedCount, collectionSize: collectionSize),
        const SizedBox(height: 18),
        _CollectionHeading(earnedCount: earnedCount),
        const SizedBox(height: 14),
        if (badges.isEmpty)
          const _EmptyCollection()
        else
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) => _BadgeCard(badge: badges[index]),
          ),
        const SizedBox(height: 14),
        _NextBadgeHint(remaining: collectionSize - earnedCount),
      ],
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({
    required this.earnedCount,
    required this.collectionSize,
  });

  final int earnedCount;
  final int collectionSize;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final progress = collectionSize == 0 ? 0.0 : earnedCount / collectionSize;
    final nextMilestone = earnedCount >= collectionSize
        ? 'Collection complete — incredible work!'
        : '${collectionSize - earnedCount} more to complete your collection';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appPalette.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Row(
        spacing: 16,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: context.appPalette.warning,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.trophy,
              size: AppIconSizes.xl,
              color: context.appPalette.surface,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 7,
              children: [
                Text(
                  'YOUR COLLECTION',
                  style: typography.overlineStrong,
                ),
                Text(
                  '$earnedCount of $collectionSize unlocked',
                  style: typography.titleLGStrong.copyWith(
                    color: context.appPalette.primary,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: context.appPalette.warning.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(context.appPalette.warning),
                  ),
                ),
                Text(
                  nextMilestone,
                  style: typography.bodyXS.copyWith(
                    color: context.appPalette.mutedForeground,
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

class _CollectionHeading extends StatelessWidget {
  const _CollectionHeading({required this.earnedCount});

  final int earnedCount;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                'Your collection',
                style: typography.titleLG.copyWith(color: context.appPalette.primary),
              ),
              Text(
                'Small wins, worth celebrating',
                style: typography.bodyXS.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$earnedCount earned',
          style: typography.bodySMStrong.copyWith(color: context.appPalette.accent),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ColoredBox(
              color: _backgroundFor(context, badge),
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SvgPicture.asset(
                    _illustrationFor(badge),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleXSStrong.copyWith(
                      color: context.appPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.bodyXS.copyWith(
                      height: 1.2,
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _backgroundFor(BuildContext context, Achievement badge) {
    return switch (badge.key) {
      'first_event' => context.appPalette.badgeFirstEventBackground,
      'conversation_starter' =>
        context.appPalette.badgeConversationStarterBackground,
      'community_supporter' =>
        context.appPalette.badgeCommunitySupporterBackground,
      'week_streak' => context.appPalette.badgeWeekStreakBackground,
      _ => switch (badge.icon) {
        'calendar' => context.appPalette.badgeFirstEventBackground,
        'message-circle' =>
          context.appPalette.badgeConversationStarterBackground,
        'heart' => context.appPalette.badgeCommunitySupporterBackground,
        'flame' => context.appPalette.badgeWeekStreakBackground,
        _ => context.appPalette.muted,
      },
    };
  }

  String _illustrationFor(Achievement badge) {
    switch (badge.key) {
      case 'first_event':
        return 'assets/images/badges/first_event_v2.svg';
      case 'conversation_starter':
        return 'assets/images/badges/conversation_starter_v2.svg';
      case 'community_supporter':
        return 'assets/images/badges/community_supporter_v2.svg';
      case 'week_streak':
        return 'assets/images/badges/week_streak_v2.svg';
    }

    return switch (badge.icon) {
      'calendar' => 'assets/images/badges/first_event_v2.svg',
      'message-circle' => 'assets/images/badges/conversation_starter_v2.svg',
      'heart' => 'assets/images/badges/community_supporter_v2.svg',
      'flame' => 'assets/images/badges/week_streak_v2.svg',
      _ => 'assets/images/badges/community_supporter_v2.svg',
    };
  }
}

class _NextBadgeHint extends StatelessWidget {
  const _NextBadgeHint({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final isComplete = remaining <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: context.appPalette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(
            LucideIcons.sparkles,
            size: AppIconSizes.defaultSize,
            color: context.appPalette.accent,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  isComplete
                      ? 'Your collection is complete'
                      : 'Your next badge is close',
                  style: typography.bodySMStrong.copyWith(
                    color: context.appPalette.primary,
                  ),
                ),
                Text(
                  isComplete
                      ? 'Keep showing up and celebrating the community.'
                      : 'Keep hosting, joining, and helping your community.',
                  style: typography.bodyXS.copyWith(
                    color: context.appPalette.mutedForeground,
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

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: context.appPalette.muted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Column(
        spacing: 10,
        children: [
          Icon(
            LucideIcons.award,
            size: AppIconSizes.xl,
            color: context.appPalette.mutedForeground,
          ),
          Text(
            'No badges unlocked yet',
            style: typography.titleXSStrong.copyWith(color: context.appPalette.primary),
          ),
          Text(
            'Join events and contribute to the community to earn your first badge.',
            textAlign: TextAlign.center,
            style: typography.bodySM.copyWith(color: context.appPalette.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Icon(icon, color: context.appPalette.mutedForeground),
          Text(
            message,
            style: context.appTypography.bodySM.copyWith(
              color: context.appPalette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
