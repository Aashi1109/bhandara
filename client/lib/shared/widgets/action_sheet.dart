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
        decoration: BoxDecoration(
          color: context.appPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: context.appPalette.border,
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
                          color: context.appPalette.primary,
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
                          color: context.appPalette.mutedForeground,
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
      color: context.appPalette.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDestructive
                ? context.appPalette.error.withValues(alpha: 0.06)
                : context.appPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDestructive
                  ? context.appPalette.error.withValues(alpha: 0.18)
                  : context.appPalette.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? context.appPalette.error.withValues(alpha: 0.1)
                      : context.appPalette.muted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: AppIconSizes.defaultSize,
                  color: isDestructive ? context.appPalette.error : context.appPalette.primary,
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
                            ? context.appPalette.error
                            : context.appPalette.primary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: typography.bodySM.copyWith(
                          color: isDestructive
                              ? context.appPalette.error.withValues(alpha: 0.8)
                              : context.appPalette.mutedForeground,
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
                    ? context.appPalette.error.withValues(alpha: 0.8)
                    : context.appPalette.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
