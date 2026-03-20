import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/achievement.dart';
import '../providers/user.dart';
import '../services/user.dart';
import '../theme/theme.dart';
import '../widgets/header.dart';

class ProfileBadgesScreen extends ConsumerWidget {
  const ProfileBadgesScreen({super.key});

  static const String routePath = '/profile/badges';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Badges'),
          Expanded(
            child: userAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
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
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final badges = snapshot.data ?? const <Achievement>[];
                    if (badges.isEmpty) {
                      return const Center(
                        child: Text(
                          'No badges unlocked yet.',
                          style: TextStyle(color: AppColors.mutedForeground),
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
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      badge.description,
                                      style: const TextStyle(
                                        fontSize: 13,
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
}
