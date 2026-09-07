import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/theme.dart';
import './button.dart';

Future<void> showAppDialog({
  required BuildContext context,
  required String title,
  required String message,
  String primaryLabel = 'OK',
  FutureOr<void> Function()? onPrimaryPressed,
  String? secondaryLabel,
  FutureOr<void> Function()? onSecondaryPressed,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'app-dialog',
    barrierColor: context.appPalette.primary.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: context.appPalette.transparent,
              child: _AppDialogCard(
                title: title,
                message: message,
                primaryLabel: primaryLabel,
                onPrimaryPressed: onPrimaryPressed,
                secondaryLabel: secondaryLabel,
                onSecondaryPressed: onSecondaryPressed,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AppDialogCard extends StatelessWidget {
  const _AppDialogCard({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.secondaryLabel,
    required this.onSecondaryPressed,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final FutureOr<void> Function()? onPrimaryPressed;
  final String? secondaryLabel;
  final FutureOr<void> Function()? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appPalette.border),
        boxShadow: [
          BoxShadow(
            color: context.appPalette.primary.withValues(alpha: 0.16),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.titleMD,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: typography.bodyMD.copyWith(color: context.appPalette.mutedForeground),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (secondaryLabel != null) ...[
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.md,
                    label: secondaryLabel,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (onSecondaryPressed != null) {
                        await onSecondaryPressed!();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AppButton(
                  size: AppButtonSize.md,
                  label: primaryLabel,
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (onPrimaryPressed != null) {
                      await onPrimaryPressed!();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
