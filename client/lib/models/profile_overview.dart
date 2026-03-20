import 'achievement.dart';
import 'event.dart';
import 'update.dart';

class ProfileOverview {
  ProfileOverview({
    required this.myEvents,
    required this.achievements,
    required this.recentActivity,
  });

  final List<Event> myEvents;
  final List<Achievement> achievements;
  final List<AppUpdate> recentActivity;
}
