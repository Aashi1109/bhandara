import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.rightElement,
    this.backgroundColor,
    this.showBorder = true,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? rightElement;
  final Color? backgroundColor;
  final bool showBorder;

  String get _subtitleText => subtitle?.trim() ?? '';
  bool get _hasSubtitle => _subtitleText.isNotEmpty;

  @override
  Size get preferredSize {
    return Size.fromHeight(_hasSubtitle ? 92 : 72);
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: _hasSubtitle ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.appPalette.surface.withValues(alpha: 0.9),
        border: showBorder
            ? Border(bottom: BorderSide(color: context.appPalette.border))
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showBack
                ? GestureDetector(
                    onTap: onBack ?? () => Navigator.maybePop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.appPalette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.appPalette.border),
                      ),
                      child: Icon(
                        LucideIcons.arrowLeft,
                        size: AppIconSizes.defaultSize,
                        color: context.appPalette.primary,
                      ),
                    ),
                  )
                : const SizedBox(width: 40),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.heading3Strong.copyWith(
                    color: context.appPalette.primary,
                  ),
                ),
                if (_hasSubtitle)
                  Text(
                    _subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.bodySM.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: rightElement ?? const SizedBox(width: 40),
          ),
        ],
      ),
    );
  }
}
