import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../utils/event_status.dart';
import './event_avatar.dart';
import '../../../shared/theme/theme.dart';

class ManagedEventCard extends StatelessWidget {
  const ManagedEventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onActions,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final status = _displayStatus(event);
    final participantCount =
        event.stats?.participantCount ?? event.participants?.length ?? 0;
    final capacity = event.capacity;
    final guestLabel = capacity == null
        ? '$participantCount guests'
        : '$participantCount / $capacity';

    return Material(
      color: context.appPalette.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appPalette.border),
            boxShadow: [
              BoxShadow(
                color: context.appPalette.primary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventAvatar(imageUrl: event.previewImageUrl),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.titleXSStrong,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _StatusPill(status: status),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'd MMM · h:mm a',
                                ).format(event.startTime),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.bodyXS.copyWith(
                                  color: context.appPalette.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(10, -4),
                    child: IconButton(
                      key: ValueKey('event-actions-${event.id}'),
                      onPressed: onActions,
                      tooltip: 'Event actions',
                      icon: const Icon(LucideIcons.moreVertical),
                      iconSize: AppIconSizes.m,
                      color: context.appPalette.mutedForeground,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.topCenter,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Icon(
                    LucideIcons.mapPin,
                    size: AppIconSizes.s,
                    color: context.appPalette.mutedForeground,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      event.location.address.isEmpty
                          ? 'Location not set'
                          : event.location.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodyXS.copyWith(
                        color: context.appPalette.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: context.appPalette.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(icon: LucideIcons.users, label: guestLabel),
                  const SizedBox(width: 14),
                  _Metric(
                    icon: LucideIcons.eye,
                    label: '${event.stats?.viewCount ?? 0}',
                  ),
                  const Spacer(),
                  Text('Manage', style: typography.bodySMStrong),
                  const SizedBox(width: 5),
                  Icon(
                    LucideIcons.arrowRight,
                    size: AppIconSizes.s,
                    color: context.appPalette.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSizes.s, color: context.appPalette.mutedForeground),
        const SizedBox(width: 5),
        Text(
          label,
          style: context.appTypography.bodyXSStrong.copyWith(
            color: context.appPalette.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = status == EventStatusValue.upcoming;
    final isOngoing = status == EventStatusValue.ongoing;
    final foreground = isUpcoming
        ? context.appPalette.warning
        : isOngoing
        ? context.appPalette.success
        : context.appPalette.mutedForeground;
    final background = (isUpcoming || isOngoing)
        ? foreground.withValues(alpha: 0.14)
        : context.appPalette.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: context.appTypography.labelXS.copyWith(color: foreground),
      ),
    );
  }
}

String _displayStatus(Event event) {
  if (event.status.toLowerCase() == 'draft') return 'draft';
  return resolveEventStatus(event);
}
