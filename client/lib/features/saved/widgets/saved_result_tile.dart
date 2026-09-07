import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';
import '../../search/services/search.dart';

class SavedResultTile extends StatelessWidget {
  const SavedResultTile({
    super.key,
    required this.result,
    required this.secondaryText,
    required this.onTap,
    required this.onUnsave,
    this.isUnsaving = false,
  });

  final SearchResult result;
  final String? secondaryText;
  final VoidCallback onTap;
  final VoidCallback onUnsave;
  final bool isUnsaving;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appPalette.border)),
        ),
        child: Row(
          children: [
            _Thumbnail(result: result),
            const SizedBox(width: 14),
            Expanded(child: _SavedItemCopy(result, secondaryText)),
            const SizedBox(width: 8),
            _SavedToggle(isLoading: isUnsaving, onPressed: onUnsave),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final imageUrl = result.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: imageUrl == null || imageUrl.isEmpty
          ? _Placeholder(type: result.type)
          : CachedNetworkImage(
              imageUrl: imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _Placeholder(type: result.type),
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: context.appPalette.muted,
      alignment: Alignment.center,
      child: Icon(
        switch (type) {
          'event' => LucideIcons.calendarDays,
          'message' => LucideIcons.messageCircle,
          'user' => LucideIcons.user,
          _ => LucideIcons.messagesSquare,
        },
        size: AppIconSizes.xl,
        color: context.appPalette.mutedForeground,
      ),
    );
  }
}

class _SavedItemCopy extends StatelessWidget {
  const _SavedItemCopy(this.result, this.secondaryText);

  final SearchResult result;
  final String? secondaryText;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final title = result.type == 'message'
        ? result.description ?? 'Open message'
        : result.title;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TypeBadge(type: result.type),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typography.titleXSStrong.copyWith(
            color: context.appPalette.primary,
            height: 1.18,
          ),
        ),
        if (secondaryText != null && secondaryText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            secondaryText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.captionMD.copyWith(
              color: context.appPalette.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final label = type == 'user' ? 'PROFILE' : type.toUpperCase();
    final background = switch (type) {
      'event' => context.appPalette.warning.withValues(alpha: 0.14),
      'thread' => context.appPalette.mutedForeground.withValues(alpha: 0.14),
      _ => context.appPalette.accent.withValues(alpha: 0.12),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: context.appTypography.labelXSStrong.copyWith(
          color: context.appPalette.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SavedToggle extends StatelessWidget {
  const _SavedToggle({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Remove from saved',
      onPressed: isLoading ? null : onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(36),
        padding: EdgeInsets.zero,
        backgroundColor: context.appPalette.error.withValues(alpha: 0.1),
      ),
      icon: isLoading
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.appPalette.accent,
              ),
            )
          : Icon(
              LucideIcons.bookmarkMinus,
              size: 17,
              color: context.appPalette.error,
            ),
    );
  }
}
