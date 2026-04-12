import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/models/event.dart';
import 'package:foody_mobile/features/events/models/search_event_item.dart';
import 'package:foody_mobile/shared/theme/theme.dart';
import 'package:foody_mobile/features/events/widgets/event_search_result_tile.dart';

void main() {
  testWidgets('shows the current event status as a badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: EventSearchResultTile(
            item: SearchEventItem(
              id: 'event-1',
              name: 'Community Dinner',
              location: const Location(
                address: 'Food Street',
                latitude: 21.1459,
                longitude: 79.0891,
              ),
              startTime: DateTime.parse('2099-03-30T18:00:00.000Z'),
              endTime: DateTime.parse('2099-03-30T20:00:00.000Z'),
              createdAt: DateTime.parse('2099-03-27T10:00:00.000Z'),
              status: 'upcoming',
            ),
            distanceLabel: '120 m away',
            createdAgoLabel: '2h ago',
          ),
        ),
      ),
    );

    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Community Dinner'), findsOneWidget);
  });
}
