import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_palette.dart';
import './app_icon_sizes.dart';
import './app_typography.dart';
import './palettes.dart';

class AppTheme {
  static AppTypography typographyFor(AppPalette p) =>
      AppTypographyTokens.forPalette(p);

  static ThemeData buildTheme(AppPalette p) {
    final typography = typographyFor(p);

    return ThemeData(
      brightness: p.brightness,
      scaffoldBackgroundColor: p.surface,
      primaryColor: p.primary,
      colorScheme: p.brightness == Brightness.dark
          ? ColorScheme.dark(
              primary: p.primary,
              surface: p.surface,
              onPrimary: p.surface,
              onSurface: p.primary,
              outline: p.border,
            )
          : ColorScheme.light(
              primary: p.primary,
              surface: p.surface,
              onPrimary: p.surface,
              onSurface: p.primary,
              outline: p.border,
            ),
      textTheme: AppTypographyTokens.baseTextThemeFor(p).copyWith(
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
      extensions: <ThemeExtension<dynamic>>[typography, p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.primary,
        elevation: 0,
        systemOverlayStyle: p.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      iconTheme: IconThemeData(
        color: p.primary,
        size: AppIconSizes.defaultSize,
      ),
      dividerColor: p.border,
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: double.infinity),
      ),
      useMaterial3: true,
    );
  }

  static TextStyle get serifFont =>
      AppTypographyTokens.serifFontFor(lightPalette);
}
