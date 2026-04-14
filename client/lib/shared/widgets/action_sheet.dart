import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/theme.dart';

class AppActionSheet extends StatelessWidget {
  const AppActionSheet({
    super.key,
    required this.children,
    this.title,
    this.description,
  });

  final List<Widget> children;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: context.appTypography.titleLGStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (description != null) ...[
                if (title != null) const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        description!,
                        style: context.appTypography.bodyBase.copyWith(
                          color: AppColors.mutedForeground,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (title != null || description != null)
                const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class AppActionSheetItem extends StatelessWidget {
  const AppActionSheetItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleXSStrong.copyWith(
                        color: isDestructive
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: typography.bodySM.copyWith(
                          color: isDestructive
                              ? AppColors.error.withValues(alpha: 0.8)
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
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
}
