import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum AppCardVariant { defaultCard, elevated, glass }

enum AppCardPadding { none, sm, md, lg, xl }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final AppCardPadding padding;
  final double borderRadius;
  final BoxBorder? border;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.defaultCard,
    this.padding = AppCardPadding.md,
    this.borderRadius = 40,
    this.border,
    this.backgroundColor,
  });

  EdgeInsets get _padding {
    switch (padding) {
      case AppCardPadding.none:
        return EdgeInsets.zero;
      case AppCardPadding.sm:
        return const EdgeInsets.all(16);
      case AppCardPadding.md:
        return const EdgeInsets.all(24);
      case AppCardPadding.lg:
        return const EdgeInsets.all(32);
      case AppCardPadding.xl:
        return const EdgeInsets.all(40);
    }
  }

  List<BoxShadow> get _shadow {
    switch (variant) {
      case AppCardVariant.defaultCard:
        return [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case AppCardVariant.elevated:
      case AppCardVariant.glass:
        return [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppColors.border),
        boxShadow: _shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
