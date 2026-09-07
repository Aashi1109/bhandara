import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../features/chat/models/chat_attachment.dart';
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

  Widget _buildImagePreview(BuildContext context, bool hasError) {
    if (file.name.toLowerCase().endsWith('.pdf')) {
      return Container(
        color: hasError
            ? context.appPalette.error.withValues(alpha: 0.08)
            : context.appPalette.muted,
        alignment: Alignment.center,
        child: Icon(
          LucideIcons.fileText,
          size: AppIconSizes.m,
          color: hasError
              ? context.appPalette.error
              : context.appPalette.primary,
        ),
      );
    }

    Widget fallback() => Container(
      color: hasError
          ? context.appPalette.error.withValues(alpha: 0.08)
          : context.appPalette.muted,
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.image,
        size: AppIconSizes.m,
        color: hasError
            ? context.appPalette.error
            : context.appPalette.mutedForeground,
      ),
    );

    if (kIsWeb) {
      return Image.network(
        file.localPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return Image.file(
      File(file.localPath),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = file.hasFailed;
    final typography = context.appTypography;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: context.appPalette.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: hasError
                ? context.appPalette.error.withValues(alpha: 0.4)
                : context.appPalette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: context.appPalette.primary.withValues(alpha: 0.08),
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
                    ? context.appPalette.error.withValues(alpha: 0.12)
                    : context.appPalette.muted,
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
                                  ? context.appPalette.error.withValues(alpha: 0.08)
                                  : context.appPalette.muted,
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.video,
                                size: AppIconSizes.m,
                                color: hasError
                                    ? context.appPalette.error
                                    : context.appPalette.mutedForeground,
                              ),
                            )
                          : _buildImagePreview(context, hasError),
                    ),
                  ),
                  if (file.isUploading)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appPalette.primary,
                      ),
                    ),
                  if (file.hasFailed)
                    Positioned.fill(
                      child: Material(
                        color: context.appPalette.transparent,
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
                                  context.appPalette.error.withValues(alpha: 0.32),
                                  context.appPalette.primary.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                            child: Icon(
                              LucideIcons.rotateCcw,
                              size: 20,
                              color: context.appPalette.surface,
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
                style: typography.bodySM.copyWith(color: context.appPalette.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  LucideIcons.x,
                  size: AppIconSizes.s,
                  color: context.appPalette.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
