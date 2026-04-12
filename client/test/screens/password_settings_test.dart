import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/settings/screens/password.dart';
import 'package:foody_mobile/shared/theme/theme.dart';
import 'package:foody_mobile/shared/widgets/button.dart';

void main() {
  testWidgets('password update button is disabled initially', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const PasswordSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_updateButton(tester).onPressed, isNull);
  });

  testWidgets('password update button enables only for a valid form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const PasswordSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'current-password');
    await tester.enterText(fields.at(1), 'Newpass1!');
    await tester.enterText(fields.at(2), 'Newpass1!');
    await tester.pump();

    expect(_updateButton(tester).onPressed, isNotNull);
  });
}

AppButton _updateButton(WidgetTester tester) {
  return tester.widget<AppButton>(
    find.widgetWithText(AppButton, 'Update Password'),
  );
}
