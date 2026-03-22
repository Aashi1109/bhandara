import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppTextArea extends StatelessWidget {
  const AppTextArea({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.onChanged,
    this.error,
    this.height,
    this.borderRadius = 16,
    this.backgroundColor,
    this.hasBorder = true,
    this.minLines = 4,
    this.maxLines,
  });

  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? error;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final bool hasBorder;
  final int minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label!,
              style: typography.overline.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder
                ? Border.all(
                    color: error != null ? AppColors.error : AppColors.border,
                  )
                : null,
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: maxLines,
            style: typography.bodyMD.copyWith(color: AppColors.primary),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: typography.bodyMD.copyWith(
                color: AppColors.mutedForeground.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              error!,
              style: typography.overline.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }
}
