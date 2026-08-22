import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/models/event.dart';
import 'package:foody_mobile/features/events/screens/my_events.dart';
import 'package:foody_mobile/features/events/widgets/managed_event_card.dart';
import 'package:foody_mobile/shared/theme/app_theme.dart';

void main() {
  testWidgets('filters managed events using compact status controls', (
    tester,
  ) async {
    final now = DateTime.now();
    final events = [
      _event(
        id: 'upcoming',
        name: 'Upcoming Supper',
        status: 'published',
        start: now.add(const Duration(days: 2)),
        end: now.add(const Duration(days: 2, hours: 2)),
      ),
      _event(
        id: 'past',
        name: 'Past Supper',
        status: 'published',
        start: now.subtract(const Duration(days: 3)),
        end: now.subtract(const Duration(days: 3, hours: -2)),
      ),
      _event(
        id: 'draft',
        name: 'Draft Supper',
        status: 'draft',
        start: now.add(const Duration(days: 10)),
        end: now.add(const Duration(days: 10, hours: 2)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: MyEventsScreen(initialEvents: events, loadRemoteImages: false),
      ),
    );

    expect(find.text('Upcoming Supper'), findsOneWidget);
    expect(find.text('Past Supper'), findsNothing);
    expect(find.text('Draft Supper'), findsNothing);

    await tester.tap(find.text('Past'));
    await tester.pump();
    expect(find.text('Past Supper'), findsOneWidget);
    expect(find.text('Upcoming Supper'), findsNothing);

    await tester.tap(find.text('Drafts'));
    await tester.pump();
    expect(find.text('Draft Supper'), findsOneWidget);
    expect(find.text('Past Supper'), findsNothing);
  });

  testWidgets('opens the event action sheet from the overflow action', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: MyEventsScreen(
          loadRemoteImages: false,
          initialEvents: [
            _event(
              id: 'upcoming',
              name: 'Spring Table',
              status: 'published',
              start: now.add(const Duration(days: 2)),
              end: now.add(const Duration(days: 2, hours: 2)),
            ),
          ],
        ),
      ),
    );

    final actionButton = find.byKey(const ValueKey('event-actions-upcoming'));
    final titleCenter = tester.getCenter(find.text('Spring Table'));
    final actionIcon = find.descendant(
      of: actionButton,
      matching: find.byType(Icon),
    );
    final actionIconCenter = tester.getCenter(actionIcon);
    expect((actionIconCenter.dy - titleCenter.dy).abs(), lessThan(8));
    final cardRight = tester.getTopRight(find.byType(ManagedEventCard)).dx;
    final actionRight = tester.getTopRight(actionButton).dx;
    expect(cardRight - actionRight, lessThanOrEqualTo(8));

    await tester.tap(actionButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('View attendees'), findsOneWidget);
    expect(find.text('Duplicate event'), findsOneWidget);
    expect(find.text('Cancel event'), findsOneWidget);
  });
}

Event _event({
  required String id,
  required String name,
  required String status,
  required DateTime start,
  required DateTime end,
}) {
  return Event(
    id: id,
    name: name,
    status: status,
    type: 'organized',
    startTime: start,
    endTime: end,
    createdBy: 'owner',
    location: const Location(address: 'The Courtyard, Bandra'),
    capacity: 80,
    participants: const [],
    stats: EventStats(
      reactionCount: 0,
      threadCount: 0,
      participantCount: 0,
      verifierCount: 0,
      mediaCount: 0,
      tagCount: 0,
      viewCount: 42,
      ratingCount: 0,
      ratingAverage: 0,
    ),
  );
}
