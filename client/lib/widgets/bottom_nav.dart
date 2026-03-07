import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';

import '../screens/explore.dart';
import '../screens/search.dart';
import '../screens/create_event.dart';
import '../screens/updates.dart';
import '../screens/profile.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    final items = [
      _NavItem(ExploreScreen.routePath, LucideIcons.compass, 'Explore'),
      _NavItem(SearchScreen.routePath, LucideIcons.heart, 'Saved'),
      _NavItem(
        CreateEventScreen.routePath,
        LucideIcons.plus,
        'Create',
        isAction: true,
      ),
      _NavItem(UpdatesScreen.routePath, LucideIcons.bell, 'Updates'),
      _NavItem(ProfileScreen.routePath, LucideIcons.user, 'Profile'),
    ];

    return Positioned(
      bottom: 32,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) {
            final isActive = currentPath == item.path;

            if (item.isAction) {
              return GestureDetector(
                onTap: () => context.go(item.path),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    size: 24,
                    color: AppColors.surface,
                  ),
                ),
              );
            }

            if (isActive) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        size: 16,
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return GestureDetector(
              onTap: () => context.go(item.path),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  item.icon,
                  size: 24,
                  color: AppColors.mutedForeground,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  final bool isAction;

  _NavItem(this.path, this.icon, this.label, {this.isAction = false});
}
