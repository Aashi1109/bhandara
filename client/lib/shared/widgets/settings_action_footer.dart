import 'package:flutter/material.dart';

import '../theme/theme.dart';
import './button.dart';

class SettingsActionFooter extends StatelessWidget {
  const SettingsActionFooter({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadable = false,
  });

  final String label;
  final dynamic Function()? onPressed;
  final bool loadable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appPalette.surface.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: context.appPalette.border)),
      ),
      child: AppButton(
        size: AppButtonSize.xl,
        fullWidth: true,
        label: label,
        loadable: loadable,
        onPressed: onPressed,
      ),
    );
  }
}
