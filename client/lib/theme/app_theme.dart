import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_icon_sizes.dart';
import 'app_typography.dart';

class AppTheme {
  static AppTypography get typography => AppTypographyTokens.typography;

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surface,
        onPrimary: AppColors.surface,
        onSurface: AppColors.primary,
        outline: AppColors.border,
      ),
      textTheme: AppTypographyTokens.baseTextTheme.copyWith(
        displayLarge: typography.displayLG,
        headlineLarge: typography.heading1,
        headlineMedium: typography.heading2,
        headlineSmall: typography.heading3,
        titleLarge: typography.titleLG,
        titleMedium: typography.titleMD,
        titleSmall: typography.titleSM,
        bodyLarge: typography.bodyLG,
        bodyMedium: typography.bodyMD,
        bodySmall: typography.bodySM,
        labelLarge: typography.labelLG,
        labelMedium: typography.labelMD,
        labelSmall: typography.labelSM,
      ),
      extensions: <ThemeExtension<dynamic>>[typography],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.primary,
        size: AppIconSizes.defaultSize,
      ),
      dividerColor: AppColors.border,
      useMaterial3: true,
    );
  }

  static TextStyle get serifFont => AppTypographyTokens.serifFont;
}
