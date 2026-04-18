import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';

class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({
    super.key,
    this.onOpenFilters,
    this.showFilterIndicator = false,
    this.controller,
    this.placeholder = 'Find food events...',
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  final VoidCallback? onOpenFilters;
  final bool showFilterIndicator;
  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        spacing: 6,
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: AppIconSizes.defaultSize,
                    color: AppColors.mutedForeground,
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
                          color: AppColors.mutedForeground.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: typography.bodyMD.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onOpenFilters != null)
            GestureDetector(
              onTap: onOpenFilters,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.slidersHorizontal,
                      size: AppIconSizes.defaultSize,
                      color: AppColors.surface,
                    ),
                  ),
                  if (showFilterIndicator)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
