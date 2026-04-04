import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/search_event_item.dart';
import '../theme/theme.dart';

class EventSearchResultTile extends StatelessWidget {
  const EventSearchResultTile({
    super.key,
    required this.item,
    required this.distanceLabel,
    required this.createdAgoLabel,
    this.onTap,
  });

  final SearchEventItem item;
  final String distanceLabel;
  final String createdAgoLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            color: AppColors.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeading(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.titleSM.copyWith(
                        color: AppColors.primary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            distanceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodySM.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          createdAgoLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodySM.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
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
