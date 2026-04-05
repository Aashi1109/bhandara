import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/achievement.dart';
import '../providers/user.dart';
import '../services/user.dart';
import '../theme/theme.dart';
import '../widgets/header.dart';
import '../widgets/skeleton.dart';

class ProfileBadgesScreen extends ConsumerWidget {
  const ProfileBadgesScreen({super.key});

  static const String routePath = '/profile/badges';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Badges'),
          Expanded(
            child: userAsync.when(
              loading: () => _buildLoadingState(),
              error: (_, _) =>
                  const Center(child: Text('Unable to load badges')),
              data: (user) {
                if (user == null) {
                  return const Center(child: Text('User not found'));
                }

                return FutureBuilder<List<Achievement>>(
                  future: userService.getUserAchievements(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    final badges = snapshot.data ?? const <Achievement>[];
                    if (badges.isEmpty) {
                      return Center(
                        child: Text(
                          'No badges unlocked yet.',
                          style: typography.bodySM.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      itemBuilder: (context, index) {
                        final badge = badges[index];
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: AppColors.muted,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconForAchievement(badge.icon),
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      badge.title,
                                      style: typography.titleSM.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      badge.description,
                                      style: typography.bodyBase.copyWith(
                                        height: 1.4,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemCount: badges.length,
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

  static IconData _iconForAchievement(String? icon) {
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

  Widget _buildLoadingState() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemBuilder: (_, index) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              AppSkeleton(width: 52, height: 52, shape: BoxShape.circle),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLine(width: 140, height: 16),
                    SizedBox(height: 10),
                    AppSkeletonLine(height: 12),
                    SizedBox(height: 8),
                    AppSkeletonLine(width: 180, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: 5,
    );
  }
}
