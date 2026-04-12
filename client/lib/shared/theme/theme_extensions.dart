import 'package:flutter/material.dart';

import './app_theme.dart';
import './app_typography.dart';

extension AppThemeContext on BuildContext {
  AppTypography get appTypography {
    final typography = Theme.of(this).extension<AppTypography>();
    if (typography == null) {
      return AppTheme.typography;
    }

    // Hot reload can keep an older ThemeExtension instance alive after new
    // typography fields are added. Accessing one of those stale fields throws a
    // type error because the backing value is still null. Fall back to the
    // canonical token set until a full restart refreshes the theme instance.
    try {
      final validation = <TextStyle>[
        typography.heading3Strong,
        typography.titleLGStrong,
        typography.bodyMDStrong,
        typography.bodySMStrong,
        typography.overlineStrong,
      ];
      if (validation.isEmpty) {
        return AppTheme.typography;
      }
      return typography;
    } catch (_) {
      return AppTheme.typography;
    }
  }
}
