import 'package:flutter/material.dart';

import '../../../shared/theme/theme.dart';
import '../utils/event_status.dart';

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusBackground(context, status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatEventStatusLabel(status).toUpperCase(),
        style: context.appTypography.labelXS.copyWith(
          color: _statusForeground(context, status),
        ),
      ),
    );
  }

  Color _statusBackground(BuildContext context, String status) {
    switch (status) {
      case EventStatusValue.ongoing:
        return context.appPalette.success.withValues(alpha: 0.14);
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
        return context.appPalette.muted;
      case EventStatusValue.upcoming:
      default:
        return context.appPalette.warning.withValues(alpha: 0.14);
    }
  }

  Color _statusForeground(BuildContext context, String status) {
    switch (status) {
      case EventStatusValue.ongoing:
        return context.appPalette.success;
      case EventStatusValue.upcoming:
        return context.appPalette.warning;
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
      default:
        return context.appPalette.mutedForeground;
    }
  }
}
