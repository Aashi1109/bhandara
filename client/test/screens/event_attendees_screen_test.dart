import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/models/event.dart';
import 'package:foody_mobile/features/events/screens/event_attendees.dart';
import 'package:foody_mobile/shared/theme/app_theme.dart';
import 'package:foody_mobile/shared/theme/palettes.dart';
import 'package:foody_mobile/shared/widgets/input.dart';
import 'package:foody_mobile/shared/widgets/remote_svg.dart';

void main() {
  testWidgets('centers the guest-list illustration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(lightPalette),
        home: const EventAttendeesScreen(
          eventName: 'Spring Table',
          attendees: [],
        ),
      ),
    );

    final illustration = tester.widget<AppRemoteSvg>(find.byType(AppRemoteSvg));
    expect(illustration.width, 230);
    expect(illustration.height, 172);
  });

  testWidgets('searches attendees and shows the scoped no-results state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(lightPalette),
        home: EventAttendeesScreen(
          eventName: 'Spring Table',
          capacity: 12,
          loadRemoteImages: false,
          attendees: [
            EventUser(id: '2', name: 'Rohan Kapoor'),
            EventUser(id: '1', name: 'Anaya Mehta'),
          ],
        ),
      ),
    );

    expect(find.text('Anaya Mehta'), findsOneWidget);
    expect(find.text('Rohan Kapoor'), findsOneWidget);
    expect(find.byType(AppInput), findsOneWidget);
    final searchInput = tester.widget<AppInput>(find.byType(AppInput));
    expect(searchInput.borderRadius, 20);
    expect(searchInput.contentPadding, const EdgeInsets.fromLTRB(14, 0, 8, 0));
    expect(searchInput.elementSpacing, 10);
    expect(searchInput.textFieldContentPadding, EdgeInsets.zero);
    expect(searchInput.trailingSpacing, 0);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();

    expect(find.text('No attendee found'), findsOneWidget);
    expect(find.text('Anaya Mehta'), findsNothing);
    expect(find.text('Rohan Kapoor'), findsNothing);
  });

  testWidgets('opens attendee sort options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(lightPalette),
        home: EventAttendeesScreen(
          eventName: 'Spring Table',
          loadRemoteImages: false,
          attendees: [EventUser(id: '1', name: 'Anaya Mehta')],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('attendee-sort')));
    await tester.pumpAndSettle();

    expect(find.text('Sort attendees'), findsOneWidget);
    expect(find.text('Name A–Z'), findsOneWidget);
    expect(find.text('Recently joined'), findsOneWidget);
    expect(find.text('Oldest joined'), findsOneWidget);
  });
}
