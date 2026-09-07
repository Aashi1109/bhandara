import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../utils/event_status.dart';
import '../../../shared/constants/app_image_urls.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/remote_svg.dart';

const String draftEventStatus = 'draft';

enum ManagedEventFilter { upcoming, past, drafts }

extension ManagedEventFilterLabel on ManagedEventFilter {
  String get label => switch (this) {
    ManagedEventFilter.upcoming => 'Upcoming',
    ManagedEventFilter.past => 'Past',
    ManagedEventFilter.drafts => 'Drafts',
  };
}

List<Event> filterManagedEvents(
  Iterable<Event> events,
  ManagedEventFilter filter, {
  DateTime? now,
}) {
  return events.where((event) {
    final rawStatus = event.status.toLowerCase();
    if (filter == ManagedEventFilter.drafts) {
      return rawStatus == draftEventStatus;
    }
    if (rawStatus == draftEventStatus) return false;
    final resolved = resolveEventStatus(event, now: now);
    return switch (filter) {
      ManagedEventFilter.upcoming =>
        resolved == EventStatusValue.upcoming ||
            resolved == EventStatusValue.ongoing,
      ManagedEventFilter.past =>
        resolved == EventStatusValue.completed ||
            resolved == EventStatusValue.cancelled,
      ManagedEventFilter.drafts => false,
    };
  }).toList();
}

class ManageEventsOverview extends StatelessWidget {
  const ManageEventsOverview({
    super.key,
    required this.eventCount,
    required this.attendeeCount,
    required this.filter,
    this.loadIllustration = true,
  });

  final int eventCount;
  final int attendeeCount;
  final ManagedEventFilter filter;
  final bool loadIllustration;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final title = switch (filter) {
      ManagedEventFilter.upcoming => '$eventCount active events',
      ManagedEventFilter.past => '$eventCount past events',
      ManagedEventFilter.drafts => '$eventCount event drafts',
    };
    final subtitle = switch (filter) {
      ManagedEventFilter.upcoming => '$attendeeCount attendees across events',
      ManagedEventFilter.past => 'Your event archive is ready',
      ManagedEventFilter.drafts => 'Continue planning when you are ready',
    };

    return Container(
      height: 92,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appPalette.muted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: typography.titleLGStrong),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySM.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          AppRemoteSvg(
            url: AppImageUrls.manageEventsOverview,
            width: 58,
            height: 58,
            semanticsLabel: 'Events overview illustration',
            fallbackIcon: LucideIcons.calendarDays,
            enabled: loadIllustration,
          ),
        ],
      ),
    );
  }
}

class ManageEventsFilters extends StatelessWidget {
  const ManageEventsFilters({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ManagedEventFilter value;
  final ValueChanged<ManagedEventFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: ManagedEventFilter.values.map((filter) {
        final selected = filter == value;
        return Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: switch (filter) {
                ManagedEventFilter.upcoming => 92,
                ManagedEventFilter.past => 64,
                ManagedEventFilter.drafts => 72,
              },
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? context.appPalette.primary : context.appPalette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? context.appPalette.primary : context.appPalette.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  filter.label,
                  style: context.appTypography.bodySMSemi.copyWith(
                    color: selected
                        ? context.appPalette.surface
                        : context.appPalette.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

Future<void> showManagedEventActions({
  required BuildContext context,
  required Event event,
  required VoidCallback onEdit,
  required VoidCallback onViewAttendees,
  required VoidCallback onDuplicate,
  required VoidCallback onCancel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.appPalette.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _ManagedEventActionsSheet(
      event: event,
      onEdit: onEdit,
      onViewAttendees: onViewAttendees,
      onDuplicate: onDuplicate,
      onCancel: onCancel,
    ),
  );
}

class _ManagedEventActionsSheet extends StatelessWidget {
  const _ManagedEventActionsSheet({
    required this.event,
    required this.onEdit,
    required this.onViewAttendees,
    required this.onDuplicate,
    required this.onCancel,
  });

  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onViewAttendees;
  final VoidCallback onDuplicate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appPalette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appPalette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(event.name, style: context.appTypography.titleLGStrong),
              const SizedBox(height: 4),
              Text(
                'Choose what you would like to manage.',
                style: context.appTypography.bodyBase.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              _ActionRow(
                icon: LucideIcons.pencil,
                label: 'Edit event',
                onTap: onEdit,
              ),
              _ActionRow(
                icon: LucideIcons.users,
                label: 'View attendees',
                color: context.appPalette.accent,
                onTap: onViewAttendees,
              ),
              _ActionRow(
                icon: LucideIcons.copy,
                label: 'Duplicate event',
                onTap: onDuplicate,
              ),
              _ActionRow(
                icon: LucideIcons.ban,
                label: 'Cancel event',
                color: context.appPalette.error,
                onTap: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.appPalette.primary;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(icon, size: AppIconSizes.defaultSize, color: color),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: context.appTypography.titleXSStrong.copyWith(
                  color: color,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: AppIconSizes.m, color: color),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
