import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/chat_attachment.dart';
import '../theme/theme.dart';

class AttachmentPill extends StatelessWidget {
  const AttachmentPill({
    super.key,
    required this.file,
    this.onTap,
    this.onRetry,
    this.onRemove,
  });

  final ChatAttachment file;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasError = file.hasFailed;
    final typography = context.appTypography;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: hasError
                ? AppColors.error.withValues(alpha: 0.4)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasError
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: file.isVideo
                          ? Container(
                              color: hasError
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : AppColors.muted,
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.video,
                                size: AppIconSizes.m,
                                color: hasError
                                    ? AppColors.error
                                    : AppColors.mutedForeground,
                              ),
                            )
                          : Image.file(
                              File(file.localPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: hasError
                                    ? AppColors.error.withValues(alpha: 0.08)
                                    : AppColors.muted,
                                alignment: Alignment.center,
                                child: Icon(
                                  LucideIcons.image,
                                  size: AppIconSizes.m,
                                  color: hasError
                                      ? AppColors.error
                                      : AppColors.mutedForeground,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (file.isUploading)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  if (file.hasFailed)
                    Positioned.fill(
                      child: Material(
                        color: AppColors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onRetry,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.error.withValues(alpha: 0.32),
                                  AppColors.primary.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.rotateCcw,
                              size: 20,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                file.name,
                style: typography.bodySM.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  LucideIcons.x,
                  size: AppIconSizes.s,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
