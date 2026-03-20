import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared UI layer avoids raw text metrics outside the theme', () {
    const guardedFiles = [
      'lib/widgets/button.dart',
      'lib/widgets/input.dart',
      'lib/widgets/app_dialog.dart',
      'lib/widgets/header.dart',
      'lib/widgets/password_requirements.dart',
      'lib/widgets/snackbar.dart',
      'lib/screens/splash.dart',
      'lib/screens/login.dart',
      'lib/screens/auth.dart',
    ];

    final fontMetricPattern = RegExp(
      r'TextStyle\s*\([^)]*(fontSize|fontWeight|letterSpacing|height)\s*:',
    );

    for (final path in guardedFiles) {
      final content = File(path).readAsStringSync();
      expect(
        fontMetricPattern.hasMatch(content),
        isFalse,
        reason: '$path should use AppTypography roles instead of raw text metrics.',
      );
    }
  });
}
