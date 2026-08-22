import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';

/// Circular event thumbnail that falls back to a calendar icon when the event
/// has no image, or when the image fails to load.
class EventAvatar extends StatelessWidget {
  const EventAvatar({super.key, this.imageUrl, this.size = 48});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.muted,
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        LucideIcons.calendar,
        size: AppIconSizes.defaultSize,
        color: AppColors.mutedForeground,
      ),
    );
  }
}
