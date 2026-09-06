import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/settings/screens/appearance.dart';
import 'package:foody_mobile/shared/providers/theme_preference.dart';
import 'package:foody_mobile/shared/theme/theme.dart';

void main() {
  testWidgets('theme row opens a preview sheet and applies the theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAppearance(tester, 'system');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Garden Table'));
    await tester.pumpAndSettle();

    expect(find.text('Grounded · seasonal · generous'), findsOneWidget);
    expect(find.text('Use Garden Table'), findsOneWidget);

    await tester.tap(find.text('Use Garden Table'));
    await tester.pumpAndSettle();

    expect(find.text('Use Garden Table'), findsNothing);
    expect(find.text('Currently selected'), findsOneWidget);
  });

  testWidgets('display modes and branded themes are mutually exclusive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAppearance(tester, 'dark');

    _expectSelected(tester, 'Dark', true);
    expect(find.text('Currently selected'), findsNothing);

    await tester.tap(find.text('Garden Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Garden Table'));
    await tester.pumpAndSettle();

    expect(find.text('Currently selected'), findsOneWidget);
    _expectSelected(tester, 'System', false);
    _expectSelected(tester, 'Light', false);
    _expectSelected(tester, 'Dark', false);
  });

  testWidgets('Clear restores the system theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAppearance(tester, harvestEmberPalette.id);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    _expectSelected(tester, 'System', true);
  });
}

Future<void> _pumpAppearance(WidgetTester tester, String selection) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themePreferenceProvider.overrideWith(
          () => _TestThemePreference(selection),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(harvestEmberPalette),
        home: const AppearanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectSelected(WidgetTester tester, String label, bool selected) {
  expect(
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .flagsCollection
        .isSelected,
    selected ? Tristate.isTrue : Tristate.isFalse,
  );
}

class _TestThemePreference extends ThemePreference {
  _TestThemePreference(this.initialSelection);

  final String initialSelection;

  @override
  Future<String> build() async => initialSelection;

  @override
  Future<void> setPreference(String id) async => state = AsyncData(id);
}
