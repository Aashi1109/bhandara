import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/theme/theme.dart';
import 'package:foody_mobile/shared/widgets/button.dart';
import 'package:foody_mobile/shared/widgets/input.dart';

void main() {
  Future<void> pumpTestApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('AppButton label uses semantic typography', (tester) async {
    await pumpTestApp(
      tester,
      const Center(child: AppButton(label: 'Continue')),
    );

    final text = tester.widget<Text>(find.text('Continue'));
    final style = text.style!;

    expect(style.fontSize, AppTheme.typography.labelMD.fontSize);
    expect(style.fontWeight, AppTheme.typography.labelMD.fontWeight);
  });

  testWidgets('AppInput label and field use semantic typography', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      const AppInput(label: 'Email', placeholder: 'chef@foodie.com'),
    );

    final labelText = tester.widget<Text>(find.text('Email'));
    expect(labelText.style!.fontSize, AppTheme.typography.labelMD.fontSize);
    expect(labelText.style!.fontWeight, AppTheme.typography.labelMD.fontWeight);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.style!.fontSize, AppTheme.typography.bodyMD.fontSize);
    expect(textField.style!.fontWeight, AppTheme.typography.bodyMD.fontWeight);
  });

  test('expanded typography tokens preserve the migration scale', () {
    final typography = AppTheme.typography;

    expect(typography.headingXL.fontSize, 44);
    expect(typography.headingXL.fontWeight, FontWeight.w900);

    expect(typography.titleXL.fontSize, 28);
    expect(typography.heading3.fontSize, 24);

    expect(typography.titleXS.fontSize, 15);
    expect(typography.titleXS.fontWeight, FontWeight.w600);

    expect(typography.bodyBase.fontSize, 13);
    expect(typography.bodyBase.fontWeight, FontWeight.w500);

    expect(typography.bodyXS.fontSize, 11);
    expect(typography.bodyMDSemi.fontWeight, FontWeight.w600);

    expect(typography.labelXS.fontSize, 8);
    expect(typography.captionMD.fontSize, 13);
    expect(typography.captionSM.fontSize, 11);
  });
}
