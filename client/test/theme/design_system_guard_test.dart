import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared UI layer avoids raw text metrics outside the theme', () {
    const guardedFiles = [
      'lib/shared/widgets/button.dart',
      'lib/shared/widgets/input.dart',
      'lib/shared/widgets/app_dialog.dart',
      'lib/shared/widgets/header.dart',
      'lib/shared/widgets/password_requirements.dart',
      'lib/shared/widgets/snackbar.dart',
      'lib/features/auth/screens/splash.dart',
      'lib/features/auth/screens/login.dart',
      'lib/features/auth/screens/auth.dart',
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
