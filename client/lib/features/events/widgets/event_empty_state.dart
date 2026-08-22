import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/remote_svg.dart';

class EventEmptyState extends StatelessWidget {
  const EventEmptyState({
    super.key,
    required this.imageUrl,
    required this.imageSemanticsLabel,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.imageWidth = 230,
    this.imageHeight = 172,
    this.loadIllustration = true,
    this.fallbackIcon = LucideIcons.utensils,
  });

  final String imageUrl;
  final String imageSemanticsLabel;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double imageWidth;
  final double imageHeight;
  final bool loadIllustration;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppRemoteSvg(
            url: imageUrl,
            width: imageWidth,
            height: imageHeight,
            semanticsLabel: imageSemanticsLabel,
            fallbackIcon: fallbackIcon,
            enabled: loadIllustration,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.titleXL.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: typography.bodyBase.copyWith(
                color: AppColors.mutedForeground,
                height: 1.45,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            IntrinsicWidth(
              child: AppButton(
                label: actionLabel,
                icon: const Icon(LucideIcons.plus),
                size: AppButtonSize.sm,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
