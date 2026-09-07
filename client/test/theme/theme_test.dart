import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/theme/theme.dart';

void main() {
  test('color theme catalog exposes unique selectable themes', () {
    final ids = appPalettes.map((palette) => palette.id).toSet();

    expect(appPalettes, hasLength(6));
    expect(ids, hasLength(appPalettes.length));
    expect(paletteById('light'), same(lightPalette));
    expect(paletteById('dark'), same(darkPalette));
    expect(paletteById('garden-table'), same(gardenTablePalette));
    expect(paletteById('unknown'), isNull);
  });

  testWidgets('AppTypography extension is available from the app theme', (
    tester,
  ) async {
    late AppTypography typography;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(lightPalette),
        home: Builder(
          builder: (context) {
            typography = context.appTypography;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(typography.heading1.fontSize, 36);
    expect(typography.heading2.fontSize, 32);
    expect(typography.bodyMD.fontSize, 14);
    expect(typography.overline.letterSpacing, 2);
  });
}
