import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/widgets/app_search_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('does not show a filter action by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppSearchBar(placeholder: 'Search saved items…')),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(LucideIcons.search), findsOneWidget);
    expect(find.byIcon(LucideIcons.slidersHorizontal), findsNothing);
    expect(find.text('Search saved items…'), findsOneWidget);
  });

  testWidgets('shows the shared optional filter action when requested', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppSearchBar(onOpenFilters: () => tapped = true)),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));

    expect(tapped, isTrue);
  });
}
