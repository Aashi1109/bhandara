import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/theme/theme.dart';
import 'package:foody_mobile/widgets/button.dart';
import 'package:foody_mobile/widgets/input.dart';

void main() {
  Future<void> pumpTestApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.theme, home: Scaffold(body: child)),
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

  testWidgets('AppInput label and field use semantic typography', (tester) async {
    await pumpTestApp(
      tester,
      const AppInput(label: 'Email', placeholder: 'chef@foodie.com'),
    );

    final labelText = tester.widget<Text>(find.text('EMAIL'));
    expect(labelText.style!.fontSize, AppTheme.typography.overline.fontSize);
    expect(
      labelText.style!.letterSpacing,
      AppTheme.typography.overline.letterSpacing,
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.style!.fontSize, AppTheme.typography.bodyMD.fontSize);
    expect(textField.style!.fontWeight, AppTheme.typography.bodyMD.fontWeight);
  });
}
