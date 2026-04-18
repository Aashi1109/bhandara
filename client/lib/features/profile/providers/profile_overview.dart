import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/achievement.dart';
import '../../../shared/models/api_response.dart';
import '../../events/models/event.dart';
import '../models/profile_overview.dart';
import '../models/update.dart';
import '../../events/services/activity.dart';
import '../../events/services/event.dart';
import '../services/user.dart';

part 'profile_overview.g.dart';

@riverpod
Future<ProfileOverview> profileOverview(Ref ref, {required String userId}) async {
  final currentUser = await userService.getCurrentUser();
  final isOwnProfile = currentUser?.id == userId;
  final results = await Future.wait([
    eventService.getEvents(createdBy: userId, limit: 50),
    userService.getUserAchievements(userId),
    activityService.getUserActivity(
      userId,
      includePrivate: isOwnProfile,
      limit: 3,
    ),
    userService.getUserImpact(userId),
  ]);

  final allEventsResult = results[0];
  final achievementsResult = results[1];
  final activityResult = results[2];
  final impactStatsResult = results[3];

  if (allEventsResult is! PaginatedResponse<Event>) {
    throw StateError('Expected paginated events response.');
  }
  if (achievementsResult is! List<Achievement>) {
    throw StateError('Expected achievements list response.');
  }
  if (activityResult is! PaginatedResponse<AppUpdate>) {
    throw StateError('Expected paginated activity response.');
  }
  if (impactStatsResult is! Map<String, dynamic>?) {
    throw StateError('Expected nullable impact stats map response.');
  }

  final allEvents = allEventsResult;
  final achievements = achievementsResult;
  final activity = activityResult;
  final impactStats = impactStatsResult;

  final myEvents =
      await Future.wait(
          allEvents.items.map((event) async {
            try {
              return await eventService.getEventPreview(event.id);
            } catch (_) {
              return event;
            }
          }),
        )
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  return ProfileOverview(
    myEvents: myEvents,
    achievements: achievements,
    recentActivity: activity.items,
    impactStats: impactStats,
  );
}
