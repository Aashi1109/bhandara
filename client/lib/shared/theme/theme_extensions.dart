import 'package:flutter/material.dart';

import './app_palette.dart';
import './app_typography.dart';
import './palettes.dart';

extension AppThemeContext on BuildContext {
  AppPalette get appPalette =>
      Theme.of(this).extension<AppPalette>() ?? lightPalette;

  AppTypography get appTypography {
    final typography = Theme.of(this).extension<AppTypography>();
    if (typography == null) {
      return AppTypographyTokens.forPalette(lightPalette);
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
        return AppTypographyTokens.forPalette(lightPalette);
      }
      return typography;
    } catch (_) {
      return AppTypographyTokens.forPalette(lightPalette);
    }
  }
}
