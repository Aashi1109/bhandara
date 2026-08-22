import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppInputError extends StatelessWidget {
  const AppInputError({
    super.key,
    required this.message,
    this.padding = EdgeInsets.zero,
  });

  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        message,
        style: context.appTypography.bodySM.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}
