import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/event_status.dart';

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatEventStatusLabel(status).toUpperCase(),
        style: context.appTypography.labelXS.copyWith(
          color: _statusForeground(status),
        ),
      ),
    );
  }

  Color _statusBackground(String status) {
    switch (status) {
      case EventStatusValue.ongoing:
        return AppColors.success.withValues(alpha: 0.14);
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
        return AppColors.muted;
      case EventStatusValue.upcoming:
      default:
        return AppColors.warning.withValues(alpha: 0.14);
    }
  }

  Color _statusForeground(String status) {
    switch (status) {
      case EventStatusValue.ongoing:
        return AppColors.success;
      case EventStatusValue.upcoming:
        return AppColors.warning;
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
      default:
        return AppColors.mutedForeground;
    }
  }
}
