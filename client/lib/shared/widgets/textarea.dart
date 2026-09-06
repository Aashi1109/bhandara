import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'input_error.dart';
import 'input_label.dart';

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
    this.focusNode,
    this.autofocus = false,
    this.uppercaseLabel = false,
    this.labelStyle,
    this.labelPadding = EdgeInsets.zero,
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
  final FocusNode? focusNode;
  final bool autofocus;
  final bool uppercaseLabel;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry labelPadding;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (label != null)
          AppInputLabel(
            label: label!,
            uppercase: uppercaseLabel,
            style: labelStyle,
            padding: labelPadding,
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? context.appPalette.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder
                ? Border.all(
                    color: error != null ? context.appPalette.error : context.appPalette.border,
                  )
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: maxLines,
            style: typography.bodyMD.copyWith(color: context.appPalette.primary),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: typography.bodyMD.copyWith(
                color: context.appPalette.mutedForeground.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (error != null) AppInputError(message: error!),
      ],
    );
  }
}
