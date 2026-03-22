import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/event.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/header.dart';
import 'profile.dart';

class EventAttendeesScreen extends StatelessWidget {
  const EventAttendeesScreen({
    super.key,
    required this.eventName,
    required this.attendees,
  });

  static const String routePath = '/event-attendees';

  final String eventName;
  final List<EventUser> attendees;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Attendees',
            subtitle: eventName,
          ),
          Expanded(
            child: attendees.isEmpty
                ? const Center(
                    child: Text(
                      'No attendees yet.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    itemCount: attendees.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final attendee = attendees[index];
                      return InkWell(
                        onTap: () => context.push(
                          ProfileScreen.routePath,
                          extra: {'userId': attendee.id},
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Avatar(
                                name: attendee.name,
                                imageUrl: attendee.avatarUrl,
                                size: 48,
                                textSize: 16,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  attendee.name ?? 'Unknown attendee',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
