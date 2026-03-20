import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Semantic text roles live here so feature code can choose intent-based names
/// instead of repeating raw font metrics. Add new roles only when the existing
/// hierarchy cannot express a genuinely new use case.
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.displayXL,
    required this.displayLG,
    required this.heading1,
    required this.heading2,
    required this.heading3,
    required this.titleLG,
    required this.titleMD,
    required this.titleSM,
    required this.bodyLG,
    required this.bodyMD,
    required this.bodySM,
    required this.labelLG,
    required this.labelMD,
    required this.labelSM,
    required this.overline,
  });

  // Splash screens and rare hero moments only.
  final TextStyle displayXL;

  // Large branded display text on standout surfaces.
  final TextStyle displayLG;

  // Primary page titles.
  final TextStyle heading1;

  // Major section headers.
  final TextStyle heading2;

  // Card titles, modal titles, and sheet headers.
  final TextStyle heading3;

  // Prominent content titles inside screens.
  final TextStyle titleLG;

  // Standard titles in lists, cards, and dense layouts.
  final TextStyle titleMD;

  // Compact item titles and tight UI blocks.
  final TextStyle titleSM;

  // Emphasized body copy or lead-in text.
  final TextStyle bodyLG;

  // Default body copy for most readable content.
  final TextStyle bodyMD;

  // Secondary, supporting, or helper copy.
  final TextStyle bodySM;

  // Button text and high-emphasis control labels.
  final TextStyle labelLG;

  // Form labels and standard UI labels.
  final TextStyle labelMD;

  // Chips, metadata, and compact helper labels.
  final TextStyle labelSM;

  // Tiny uppercase markers, badge text, and section kickers above headings.
  final TextStyle overline;

  @override
  AppTypography copyWith({
    TextStyle? displayXL,
    TextStyle? displayLG,
    TextStyle? heading1,
    TextStyle? heading2,
    TextStyle? heading3,
    TextStyle? titleLG,
    TextStyle? titleMD,
    TextStyle? titleSM,
    TextStyle? bodyLG,
    TextStyle? bodyMD,
    TextStyle? bodySM,
    TextStyle? labelLG,
    TextStyle? labelMD,
    TextStyle? labelSM,
    TextStyle? overline,
  }) {
    return AppTypography(
      displayXL: displayXL ?? this.displayXL,
      displayLG: displayLG ?? this.displayLG,
      heading1: heading1 ?? this.heading1,
      heading2: heading2 ?? this.heading2,
      heading3: heading3 ?? this.heading3,
      titleLG: titleLG ?? this.titleLG,
      titleMD: titleMD ?? this.titleMD,
      titleSM: titleSM ?? this.titleSM,
      bodyLG: bodyLG ?? this.bodyLG,
      bodyMD: bodyMD ?? this.bodyMD,
      bodySM: bodySM ?? this.bodySM,
      labelLG: labelLG ?? this.labelLG,
      labelMD: labelMD ?? this.labelMD,
      labelSM: labelSM ?? this.labelSM,
      overline: overline ?? this.overline,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;

    return AppTypography(
      displayXL: TextStyle.lerp(displayXL, other.displayXL, t) ?? displayXL,
      displayLG: TextStyle.lerp(displayLG, other.displayLG, t) ?? displayLG,
      heading1: TextStyle.lerp(heading1, other.heading1, t) ?? heading1,
      heading2: TextStyle.lerp(heading2, other.heading2, t) ?? heading2,
      heading3: TextStyle.lerp(heading3, other.heading3, t) ?? heading3,
      titleLG: TextStyle.lerp(titleLG, other.titleLG, t) ?? titleLG,
      titleMD: TextStyle.lerp(titleMD, other.titleMD, t) ?? titleMD,
      titleSM: TextStyle.lerp(titleSM, other.titleSM, t) ?? titleSM,
      bodyLG: TextStyle.lerp(bodyLG, other.bodyLG, t) ?? bodyLG,
      bodyMD: TextStyle.lerp(bodyMD, other.bodyMD, t) ?? bodyMD,
      bodySM: TextStyle.lerp(bodySM, other.bodySM, t) ?? bodySM,
      labelLG: TextStyle.lerp(labelLG, other.labelLG, t) ?? labelLG,
      labelMD: TextStyle.lerp(labelMD, other.labelMD, t) ?? labelMD,
      labelSM: TextStyle.lerp(labelSM, other.labelSM, t) ?? labelSM,
      overline: TextStyle.lerp(overline, other.overline, t) ?? overline,
    );
  }
}

class AppTypographyTokens {
  AppTypographyTokens._();

  static final TextTheme baseTextTheme = GoogleFonts.plusJakartaSansTextTheme()
      .apply(
        bodyColor: AppColors.primary,
        displayColor: AppColors.primary,
      );

  static TextStyle _baseStyle({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color color = AppColors.primary,
  }) {
    return baseTextTheme.bodyMedium!.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _serifStyle({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    FontStyle fontStyle = FontStyle.normal,
    Color color = AppColors.primary,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      color: color,
    );
  }

  static final AppTypography typography = AppTypography(
    displayXL: _serifStyle(
      size: 90,
      weight: FontWeight.w700,
      height: 1,
      letterSpacing: -5,
      fontStyle: FontStyle.italic,
    ),
    displayLG: _serifStyle(
      size: 48,
      weight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -1.2,
    ),
    heading1: _baseStyle(
      size: 36,
      weight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.5,
    ),
    heading2: _baseStyle(
      size: 32,
      weight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -1,
    ),
    heading3: _baseStyle(
      size: 24,
      weight: FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.5,
    ),
    titleLG: _baseStyle(size: 20, weight: FontWeight.w700, height: 1.2),
    titleMD: _baseStyle(size: 18, weight: FontWeight.w700, height: 1.2),
    titleSM: _baseStyle(size: 16, weight: FontWeight.w700, height: 1.25),
    bodyLG: _baseStyle(
      size: 16,
      weight: FontWeight.w500,
      height: 1.5,
      color: AppColors.mutedForeground,
    ),
    bodyMD: _baseStyle(
      size: 14,
      weight: FontWeight.w500,
      height: 1.5,
      color: AppColors.primary,
    ),
    bodySM: _baseStyle(
      size: 12,
      weight: FontWeight.w500,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    labelLG: _baseStyle(size: 16, weight: FontWeight.w700, height: 1.2),
    labelMD: _baseStyle(size: 14, weight: FontWeight.w700, height: 1.2),
    labelSM: _baseStyle(size: 10, weight: FontWeight.w700, height: 1.2),
    overline: _baseStyle(
      size: 10,
      weight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 2,
      color: AppColors.mutedForeground,
    ),
  );

  static TextStyle get serifFont =>
      GoogleFonts.playfairDisplay(color: AppColors.primary);
}
