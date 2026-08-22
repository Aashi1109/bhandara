import 'package:flutter/material.dart';

import '../models/search_event_item.dart';
import '../../../shared/theme/theme.dart';
import '../utils/event_status.dart';
import './event_avatar.dart';
import './event_status_badge.dart';

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
    final resolvedStatus = deriveEventStatus(
      startTime: item.startTime,
      endTime: item.endTime,
      currentStatus: item.status,
    );

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        EventStatusBadge(status: resolvedStatus),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.titleSM,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            distanceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyMDSemi,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          createdAgoLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodyMDSemi,
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

  Widget _buildLeading() => EventAvatar(imageUrl: item.imageUrl);
}
