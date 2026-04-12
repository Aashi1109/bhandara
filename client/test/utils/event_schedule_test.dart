import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/utils/event_schedule.dart';

void main() {
  test('normalizeEventEndDateTime keeps end after start', () {
    final start = DateTime(2026, 3, 20, 18, 0);
    final result = normalizeEventEndDateTime(
      start: start,
      proposedEnd: start.subtract(const Duration(minutes: 10)),
    );

    expect(result, start.add(const Duration(minutes: 30)));
  });

  test('normalizeEventEndDateTime caps end to seven days', () {
    final start = DateTime(2026, 3, 20, 18, 0);
    final result = normalizeEventEndDateTime(
      start: start,
      proposedEnd: start.add(const Duration(days: 9)),
    );

    expect(result, start.add(const Duration(days: 7)));
  });
}
