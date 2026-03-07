import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/header.dart';
import '../widgets/bottom_nav.dart';

class UpdatesScreen extends StatelessWidget {
  static const String routePath = '/updates';
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unread count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          '3 UNREAD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _sectionLabel('TODAY'),
                      const SizedBox(height: 12),
                      _notif(
                        LucideIcons.messageSquare,
                        'Lisa replied to your thread',
                        '"Great tip about the parking! We should..."',
                        '2m ago',
                        true,
                        AppColors.primary,
                      ),
                      _notif(
                        LucideIcons.mapPin,
                        'New event near you',
                        'Free Tacos at Downtown Park — 0.3 mi away',
                        '15m ago',
                        true,
                        AppColors.accent,
                      ),
                      _notif(
                        LucideIcons.award,
                        'Achievement unlocked!',
                        'You earned the "Week Streak" badge 🔥',
                        '1h ago',
                        true,
                        const Color(0xFFD97706),
                      ),
                      const SizedBox(height: 32),

                      _sectionLabel('EARLIER'),
                      const SizedBox(height: 12),
                      _notif(
                        LucideIcons.messageCircle,
                        'Sarah mentioned you',
                        '"@jane check out this amazing spread!"',
                        '3h ago',
                        false,
                        AppColors.mutedForeground,
                      ),
                      _notif(
                        LucideIcons.heart,
                        'Your event got 12 saves',
                        'Community Pizza Night is trending',
                        '5h ago',
                        false,
                        AppColors.mutedForeground,
                      ),
                      _notif(
                        LucideIcons.users,
                        'Marcus joined your event',
                        'Downtown Burger Bash — 24 attending',
                        '8h ago',
                        false,
                        AppColors.mutedForeground,
                      ),
                      _notif(
                        LucideIcons.checkCircle2,
                        'Event completed',
                        'BBQ Cookout ended with 45 participants',
                        '1d ago',
                        false,
                        AppColors.mutedForeground,
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

  Widget _notif(
    IconData icon,
    String title,
    String body,
    String time,
    bool unread,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unread
            ? AppColors.muted.withValues(alpha: 0.5)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unread
                  ? accentColor.withValues(alpha: 0.1)
                  : AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: unread ? accentColor : AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: unread
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground.withValues(
                      alpha: unread ? 1 : 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }
}
