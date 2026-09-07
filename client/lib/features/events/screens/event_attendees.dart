import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../../../shared/constants/app_image_urls.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/input.dart';
import '../widgets/event_empty_state.dart';
import '../../profile/screens/profile.dart';

enum _AttendeeSort { name, recentlyJoined, oldestJoined }

class EventAttendeesScreen extends StatefulWidget {
  const EventAttendeesScreen({
    super.key,
    required this.eventName,
    required this.attendees,
    this.capacity,
    this.loadRemoteImages = true,
  });

  static const String routePath = '/event-attendees';

  final String eventName;
  final List<EventUser> attendees;
  final int? capacity;
  final bool loadRemoteImages;

  @override
  State<EventAttendeesScreen> createState() => _EventAttendeesScreenState();
}

class _EventAttendeesScreenState extends State<EventAttendeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final Map<String, int> _sourceIndexById;
  _AttendeeSort _sort = _AttendeeSort.name;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sourceIndexById = {
      for (var index = 0; index < widget.attendees.length; index++)
        widget.attendees[index].id: index,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EventUser> get _visibleAttendees {
    final query = _query.trim().toLowerCase();
    final attendees = widget.attendees.where((attendee) {
      if (query.isEmpty) return true;
      return (attendee.name ?? '').toLowerCase().contains(query);
    }).toList();

    attendees.sort((a, b) {
      return switch (_sort) {
        _AttendeeSort.name => (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase(),
        ),
        _AttendeeSort.recentlyJoined => (_sourceIndexById[b.id] ?? 0).compareTo(
          _sourceIndexById[a.id] ?? 0,
        ),
        _AttendeeSort.oldestJoined => (_sourceIndexById[a.id] ?? 0).compareTo(
          _sourceIndexById[b.id] ?? 0,
        ),
      };
    });
    return attendees;
  }

  int? get _spotsRemaining {
    final capacity = widget.capacity;
    if (capacity == null) return null;
    return (capacity - widget.attendees.length).clamp(0, capacity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          AppHeader(title: 'Attendees', subtitle: widget.eventName),
          Expanded(
            child: widget.attendees.isEmpty
                ? _buildEmptyState()
                : _buildDirectory(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EventEmptyState(
      imageUrl: AppImageUrls.emptyEventAttendees,
      imageSemanticsLabel:
          'Open guest register with a pen, place cards, and a small plant',
      fallbackIcon: LucideIcons.users,
      title: 'Your table is waiting',
      description:
          'No one has joined yet. Guests will appear here as soon as they RSVP.',
      imageWidth: 230,
      imageHeight: 172,
      loadIllustration: widget.loadRemoteImages,
    );
  }

  Widget _buildDirectory() {
    final attendees = _visibleAttendees;
    return LayoutBuilder(
      builder: (context, constraints) {
        final remainingHeight = constraints.maxHeight - 228;
        final emptyStateHeight = remainingHeight > 380
            ? remainingHeight
            : 380.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            _buildSummary(),
            const SizedBox(height: 14),
            _buildSearch(),
            const SizedBox(height: 18),
            _buildDirectoryHeader(attendees.length),
            const SizedBox(height: 4),
            if (attendees.isEmpty)
              SizedBox(
                key: const ValueKey('attendee-search-empty-area'),
                height: emptyStateHeight,
                child: _buildSearchEmptyState(),
              )
            else
              ...attendees.map(_buildAttendeeRow),
          ],
        );
      },
    );
  }

  Widget _buildSummary() {
    final typography = context.appTypography;
    final spotsRemaining = _spotsRemaining;
    return SizedBox(
      height: 66,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.attendees.length} attendees',
                  style: typography.titleLGStrong,
                ),
                const SizedBox(height: 3),
                Text(
                  spotsRemaining == null
                      ? 'Guest list'
                      : '$spotsRemaining spots remaining',
                  style: typography.bodySM.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.appPalette.muted,
              shape: BoxShape.circle,
              border: Border.all(color: context.appPalette.border),
            ),
            child: Icon(
              LucideIcons.users,
              size: AppIconSizes.defaultSize,
              color: context.appPalette.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return AppInput(
      controller: _searchController,
      placeholder: 'Search attendees',
      onChanged: (value) => setState(() => _query = value),
      icon: const Icon(LucideIcons.search),
      contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      elementSpacing: 10,
      textFieldContentPadding: EdgeInsets.zero,
      trailingSpacing: 0,
      rightElement: IconButton(
        key: const ValueKey('attendee-sort'),
        tooltip: 'Sort attendees',
        onPressed: _showSortOptions,
        icon: const Icon(LucideIcons.slidersHorizontal),
        iconSize: AppIconSizes.m,
        color: context.appPalette.primary,
      ),
      backgroundColor: context.appPalette.muted,
      hasBorder: false,
    );
  }

  Widget _buildDirectoryHeader(int resultCount) {
    final label = _query.trim().isEmpty ? 'ALL ATTENDEES' : 'SEARCH RESULTS';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.appTypography.overlineEmphasis),
        Text(
          _sort == _AttendeeSort.name ? 'A–Z' : '$resultCount results',
          style: context.appTypography.bodyXSStrong.copyWith(
            color: context.appPalette.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendeeRow(EventUser attendee) {
    return InkWell(
      onTap: () =>
          context.push(ProfileScreen.routePath, extra: {'userId': attendee.id}),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appPalette.border)),
        ),
        child: Row(
          children: [
            Avatar(
              name: attendee.name,
              imageUrl: attendee.avatarUrl,
              size: 42,
              textSize: 14,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                attendee.name ?? 'Unknown attendee',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.titleXSStrong,
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: AppIconSizes.m,
              color: context.appPalette.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return EventEmptyState(
      imageUrl: AppImageUrls.emptyAttendeeSearch,
      imageSemanticsLabel:
          'Open guest register with a pen and blank place cards',
      fallbackIcon: LucideIcons.searchX,
      title: 'No attendee found',
      description: 'Check the spelling or try a different name.',
      imageWidth: 210,
      imageHeight: 154,
      actionLabel: 'Clear search',
      onAction: () {
        _searchController.clear();
        setState(() => _query = '');
      },
      loadIllustration: widget.loadRemoteImages,
    );
  }

  void _showSortOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appPalette.transparent,
      builder: (context) => _AttendeeSortSheet(
        value: _sort,
        onChanged: (value) {
          Navigator.of(context).pop();
          setState(() => _sort = value);
        },
      ),
    );
  }
}

class _AttendeeSortSheet extends StatelessWidget {
  const _AttendeeSortSheet({required this.value, required this.onChanged});

  final _AttendeeSort value;
  final ValueChanged<_AttendeeSort> onChanged;

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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
              Text(
                'Sort attendees',
                style: context.appTypography.titleLGStrong,
              ),
              const SizedBox(height: 8),
              _SortRow(
                label: 'Name A–Z',
                selected: value == _AttendeeSort.name,
                onTap: () => onChanged(_AttendeeSort.name),
              ),
              _SortRow(
                label: 'Recently joined',
                selected: value == _AttendeeSort.recentlyJoined,
                onTap: () => onChanged(_AttendeeSort.recentlyJoined),
              ),
              _SortRow(
                label: 'Oldest joined',
                selected: value == _AttendeeSort.oldestJoined,
                onTap: () => onChanged(_AttendeeSort.oldestJoined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: context.appTypography.bodyMDSemi),
            ),
            if (selected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.appPalette.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  size: AppIconSizes.m,
                  color: context.appPalette.surface,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
