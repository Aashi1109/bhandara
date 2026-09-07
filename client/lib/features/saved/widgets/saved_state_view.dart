import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/skeleton.dart';

class SavedStateView extends StatelessWidget {
  const SavedStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: context.appPalette.muted,
                shape: BoxShape.circle,
                border: Border.all(color: context.appPalette.border),
              ),
              child: Icon(icon, size: 36, color: context.appPalette.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.appTypography.titleLGStrong.copyWith(
                color: context.appPalette.primary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: context.appTypography.bodyMD.copyWith(
                  color: context.appPalette.mutedForeground,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: actionLabel,
              icon: Icon(
                icon == LucideIcons.cloudOff
                    ? LucideIcons.refreshCw
                    : LucideIcons.compass,
              ),
              size: AppButtonSize.md,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class SavedLoadingList extends StatelessWidget {
  const SavedLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
      children: List.generate(4, (index) => const _LoadingRow()),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appPalette.border)),
      ),
      child: const Row(
        children: [
          AppSkeleton(
            width: 72,
            height: 72,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 52, height: 12),
                SizedBox(height: 8),
                AppSkeletonLine(height: 14),
                SizedBox(height: 8),
                AppSkeletonLine(width: 126, height: 10),
              ],
            ),
          ),
          SizedBox(width: 8),
          AppSkeleton(width: 36, height: 36, shape: BoxShape.circle),
        ],
      ),
    );
  }
}
