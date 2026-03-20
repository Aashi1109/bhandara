import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/theme/theme.dart';

void main() {
  testWidgets('AppTypography extension is available from the app theme', (
    tester,
  ) async {
    late AppTypography typography;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
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
