import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/theme.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.placeholder = 'Search…',
    this.onChanged,
    this.onTap,
    this.onOpenFilters,
    this.showFilterIndicator = false,
    this.readOnly = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onOpenFilters;
  final bool showFilterIndicator;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appPalette.muted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: AppIconSizes.defaultSize,
            color: context.appPalette.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: typography.bodyMD.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: typography.bodyMD.copyWith(color: context.appPalette.primary),
            ),
          ),
          if (onOpenFilters != null) ...[
            const SizedBox(width: 8),
            _FilterButton(
              onPressed: onOpenFilters!,
              showIndicator: showFilterIndicator,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onPressed, required this.showIndicator});

  final VoidCallback onPressed;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.slidersHorizontal,
              size: AppIconSizes.m,
              color: context.appPalette.primary,
            ),
          ),
          if (showIndicator)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: context.appPalette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.appPalette.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
