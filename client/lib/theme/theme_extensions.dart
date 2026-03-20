import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_typography.dart';

extension AppThemeContext on BuildContext {
  AppTypography get appTypography {
    return Theme.of(this).extension<AppTypography>() ?? AppTheme.typography;
  }
}
