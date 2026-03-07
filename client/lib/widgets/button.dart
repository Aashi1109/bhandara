import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum AppButtonVariant { primary, secondary, ghost, outline }

enum AppButtonSize { sm, md, lg, xl }

class AppButton extends StatelessWidget {
  final AppButtonVariant variant;
  final AppButtonSize size;
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final Widget? icon;
  final bool fullWidth;
  final MainAxisAlignment mainAxisAlignment;
  final Widget? iconRight;

  const AppButton({
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.iconRight,
    this.fullWidth = false,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  double get _height {
    switch (size) {
      case AppButtonSize.sm:
        return 40;
      case AppButtonSize.md:
        return 48;
      case AppButtonSize.lg:
        return 56;
      case AppButtonSize.xl:
        return 64;
    }
  }

  double get _horizontalPadding {
    switch (size) {
      case AppButtonSize.sm:
        return 16;
      case AppButtonSize.md:
        return 24;
      case AppButtonSize.lg:
        return 32;
      case AppButtonSize.xl:
        return 40;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.sm:
        return 12;
      case AppButtonSize.md:
        return 14;
      case AppButtonSize.lg:
        return 16;
      case AppButtonSize.xl:
        return 18;
    }
  }

  double get _borderRadius {
    switch (size) {
      case AppButtonSize.sm:
        return 12;
      case AppButtonSize.md:
        return 16;
      case AppButtonSize.lg:
        return 16;
      case AppButtonSize.xl:
        return 24;
    }
  }

  Color get _backgroundColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.muted;
      case AppButtonVariant.ghost:
        return AppColors.transparent;
      case AppButtonVariant.outline:
        return AppColors.transparent;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.surface;
      case AppButtonVariant.secondary:
        return AppColors.primary;
      case AppButtonVariant.ghost:
        return AppColors.primary;
      case AppButtonVariant.outline:
        return AppColors.primary;
    }
  }

  BoxBorder? get _border {
    switch (variant) {
      case AppButtonVariant.outline:
      case AppButtonVariant.secondary:
        return Border.all(color: AppColors.border);
      default:
        return null;
    }
  }

  List<BoxShadow>? get _shadow {
    if (variant == AppButtonVariant.primary) {
      return [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: mainAxisAlignment,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: _foregroundColor,
                  size: _fontSize + 4,
                ),
                child: icon!,
              ),
              const SizedBox(width: 8),
            ],
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w700,
                  color: _foregroundColor,
                ),
              ),
            if (iconRight != null) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(
                  color: _foregroundColor,
                  size: _fontSize + 4,
                ),
                child: iconRight!,
              ),
            ],
          ],
        );

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: _height,
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(_borderRadius),
          border: _border,
          boxShadow: _shadow,
        ),
        child: Center(child: content),
      ),
    );
  }
}
