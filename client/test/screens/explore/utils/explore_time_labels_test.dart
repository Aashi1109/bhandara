import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/screens/explore/utils/explore_time_labels.dart';

void main() {
  group('formatExploreRelativeTime', () {
    final now = DateTime(2026, 4, 11, 12);

    test('shows day and hour units instead of unreadable total hours', () {
      final start = now.add(const Duration(hours: 95, minutes: 17));
      final end = start.add(const Duration(hours: 3));

      expect(
        formatExploreRelativeTime(start, end, now: now),
        'Starts in 3 days 23 hr',
      );
    });

    test('shows combined hours and minutes for near upcoming events', () {
      final start = now.add(const Duration(hours: 5, minutes: 17));
      final end = start.add(const Duration(hours: 2));

      expect(
        formatExploreRelativeTime(start, end, now: now),
        'Starts in 5 hr 17 min',
      );
    });

    test('shows time left for ongoing events', () {
      final start = now.subtract(const Duration(hours: 1));
      final end = now.add(const Duration(hours: 2, minutes: 5));

      expect(
        formatExploreRelativeTime(start, end, now: now),
        'Ends in 2 hr 5 min',
      );
    });

    test('shows ended for completed events', () {
      final start = now.subtract(const Duration(hours: 5));
      final end = now.subtract(const Duration(minutes: 2));

      expect(formatExploreRelativeTime(start, end, now: now), 'Ended');
    });
  });
}
