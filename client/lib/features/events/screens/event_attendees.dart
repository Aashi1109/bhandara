import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/event.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/header.dart';
import '../../profile/screens/profile.dart';

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
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(title: 'Attendees', subtitle: eventName),
          Expanded(
            child: attendees.isEmpty
                ? Center(
                    child: Text(
                      'No attendees yet.',
                      style: typography.bodyMDSemi.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    itemCount: attendees.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
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
                                  style: typography.titleSM.copyWith(
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
