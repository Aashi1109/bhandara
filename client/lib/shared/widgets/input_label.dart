import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppInputLabel extends StatelessWidget {
  const AppInputLabel({
    super.key,
    required this.label,
    this.uppercase = false,
    this.style,
    this.padding = EdgeInsets.zero,
  });

  final String label;
  final bool uppercase;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style:
            style ??
            context.appTypography.labelMD.copyWith(
              color: context.appPalette.primary,
              height: 1.2,
            ),
      ),
    );
  }
}
