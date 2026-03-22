import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/event.dart';
import '../services/event.dart';
import '../services/user.dart';
import '../theme/theme.dart';
import '../widgets/app_pull_to_refresh.dart';
import '../widgets/button.dart';
import '../widgets/header.dart';
import 'create_event.dart';
import 'event_detail.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  static const String routePath = '/profile/my-events';

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  bool _isLoading = true;
  List<Event> _events = const [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final user = await userService.getCurrentUser();
      final response = await eventService.getEvents(
        createdBy: user?.id,
        limit: 50,
      );
      final myEvents =
          await Future.wait(
              response.items.map((event) async {
                try {
                  return await eventService.getEventPreview(event.id);
                } catch (_) {
                  return event;
                }
              }),
            )
            ..sort((a, b) => b.startTime.compareTo(a.startTime));

      if (!mounted) return;
      setState(() {
        _events = myEvents;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Widget _buildEventCard(Event event) {
    return GestureDetector(
      onTap: () => context.go(
        EventDetailScreen.routePath.replaceAll(':id', event.id),
        extra: event,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEE, d MMM • h:mm a').format(event.startTime),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.location.address,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _engagementMeta(
                  LucideIcons.eye,
                  '${event.stats?.viewCount ?? 0} views',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _engagementMeta(
                    LucideIcons.star,
                    event.stats != null && event.stats!.ratingCount > 0
                        ? '${event.stats!.ratingAverage.toStringAsFixed(1)} (${event.stats!.ratingCount})'
                        : 'No ratings',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Manage My Events'),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : AppPullToRefresh(
                    onRefresh: _loadEvents,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: _events.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.calendarDays,
                                size: AppIconSizes.hero,
                                color: AppColors.mutedForeground,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'You have not created any events yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppButton(
                                label: 'Create Event',
                                size: AppButtonSize.lg,
                                onPressed: () =>
                                    context.go(CreateEventScreen.routePath),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _events.length; i++) ...[
                                _buildEventCard(_events[i]),
                                if (i != _events.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _engagementMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Icon(icon, size: AppIconSizes.s, color: AppColors.mutedForeground),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
