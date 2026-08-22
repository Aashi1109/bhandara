import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/auth/screens/success.dart';
import 'package:foody_mobile/features/events/models/event.dart';

void main() {
  testWidgets('renders the created event summary and actions', (tester) async {
    final start = DateTime(2026, 5, 18, 19, 30);
    final event = Event(
      id: 'event-1',
      name: 'Spring Table Supper Club',
      status: 'published',
      type: 'custom',
      startTime: start,
      endTime: start.add(const Duration(hours: 2, minutes: 30)),
      createdBy: 'user-1',
      location: const Location(address: 'The Courtyard, Bandra'),
      capacity: 24,
      tags: [Tag(id: 'food', name: 'Food')],
      media: [
        Media(
          id: 'media-1',
          url: 'https://example.com/cover.jpg',
          type: 'image',
        ),
        Media(
          id: 'media-2',
          url: 'https://example.com/menu.pdf',
          type: 'document',
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: SuccessScreen(event: event)));
    await tester.pump();

    expect(find.text('Your table is set.'), findsOneWidget);
    expect(find.text('Spring Table Supper Club'), findsWidgets);
    expect(find.text('FOOD · 24 spots'), findsOneWidget);
    expect(find.text('2 attachments'), findsOneWidget);
    expect(find.byKey(const ValueKey('success_share_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('success_view_event_button')),
      findsOneWidget,
    );
  });
}
