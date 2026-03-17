import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum AppButtonVariant { primary, secondary, ghost, outline }

enum AppButtonSize { sm, md, lg, xl }

class AppButton extends StatefulWidget {
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
    this.isLoading = false,
    this.loadable = false,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final AppButtonVariant variant;
  final AppButtonSize size;
  final dynamic Function()? onPressed;
  final Widget? child;
  final String? label;
  final Widget? icon;
  final bool fullWidth;
  final bool isLoading;
  final bool loadable;
  final MainAxisAlignment mainAxisAlignment;
  final Widget? iconRight;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _internalLoading = false;

  double get _height {
    switch (widget.size) {
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
    switch (widget.size) {
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
    switch (widget.size) {
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
    switch (widget.size) {
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
    switch (widget.variant) {
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
    switch (widget.variant) {
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
    switch (widget.variant) {
      case AppButtonVariant.outline:
      case AppButtonVariant.secondary:
        return Border.all(color: AppColors.border);
      default:
        return null;
    }
  }

  List<BoxShadow>? get _shadow {
    if (widget.variant == AppButtonVariant.primary) {
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
    final isLoading = widget.isLoading || _internalLoading;

    final loadingIndicator = SizedBox(
      width: _fontSize + 4,
      height: _fontSize + 4,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(_foregroundColor),
      ),
    );

    final hasContent =
        widget.label != null || widget.icon != null || widget.iconRight != null;
    final showBeside = isLoading && hasContent;
    final showOnlyLoading = isLoading && !hasContent;

    final content = showOnlyLoading
        ? loadingIndicator
        : widget.child ??
        Row(
          mainAxisSize: widget.fullWidth
              ? MainAxisSize.max
              : MainAxisSize.min,
          mainAxisAlignment: widget.mainAxisAlignment,
          children: [
            if (widget.icon != null && !isLoading) ...[
              IconTheme(
                data: IconThemeData(
                  color: _foregroundColor,
                  size: _fontSize + 4,
                ),
                child: widget.icon!,
              ),
              const SizedBox(width: 8),
            ],
            if (widget.label != null)
              Flexible(
                child: Text(
                  widget.label!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w700,
                    color: _foregroundColor,
                  ),
                ),
              ),
            if (widget.iconRight != null && !isLoading) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(
                  color: _foregroundColor,
                  size: _fontSize + 4,
                ),
                child: widget.iconRight!,
              ),
            ],
            if (showBeside) ...[
              const SizedBox(width: 8),
              loadingIndicator,
            ],
          ],
        );

    return GestureDetector(
      onTap: isLoading
          ? null
          : () async {
        if (widget.onPressed == null) return;

        if (widget.loadable) {
          if (mounted) setState(() => _internalLoading = true);
        }

        try {
          await widget.onPressed!();
        } finally {
          if (mounted && widget.loadable) {
            setState(() => _internalLoading = false);
          }
        }
      },
      child: Container(
        height: _height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
        decoration: BoxDecoration(
          color: isLoading
              ? _backgroundColor.withValues(alpha: 0.5)
              : _backgroundColor,
          borderRadius: BorderRadius.circular(_borderRadius),
          border: _border,
          boxShadow: _shadow,
        ),
        child: Center(child: content),
      ),
    );
  }
}
