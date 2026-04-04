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
    required this.headingXL,
    required this.heading1,
    required this.heading2,
    required this.heading3,
    required this.titleXL,
    required this.titleLG,
    required this.titleMD,
    required this.titleSM,
    required this.titleXS,
    required this.bodyLG,
    required this.bodyMD,
    required this.bodyMDSemi,
    required this.bodyBase,
    required this.bodySM,
    required this.bodyXS,
    required this.labelLG,
    required this.labelMD,
    required this.labelSM,
    required this.labelXS,
    required this.captionMD,
    required this.captionSM,
    required this.overline,
  });

  // Splash screens and rare hero moments only.
  final TextStyle displayXL;

  // Large branded display text on standout surfaces.
  final TextStyle displayLG;

  // Standout non-serif heading used when heading1 is too small.
  final TextStyle headingXL;

  // Primary page titles.
  final TextStyle heading1;

  // Major section headers.
  final TextStyle heading2;

  // Card titles, modal titles, and sheet headers.
  final TextStyle heading3;

  // Large content titles below heading3 and above titleLG.
  final TextStyle titleXL;

  // Prominent content titles inside screens.
  final TextStyle titleLG;

  // Standard titles in lists, cards, and dense layouts.
  final TextStyle titleMD;

  // Compact item titles and tight UI blocks.
  final TextStyle titleSM;

  // Dense list rows and utility titles that are smaller than titleSM.
  final TextStyle titleXS;

  // Emphasized body copy or lead-in text.
  final TextStyle bodyLG;

  // Default body copy for most readable content.
  final TextStyle bodyMD;

  // Semibold body copy for emphasized rows without jumping to title styles.
  final TextStyle bodyMDSemi;

  // Transitional helper/body text used heavily across sheets and cards.
  final TextStyle bodyBase;

  // Secondary, supporting, or helper copy.
  final TextStyle bodySM;

  // Tiny readable supporting copy such as timestamps.
  final TextStyle bodyXS;

  // Button text and high-emphasis control labels.
  final TextStyle labelLG;

  // Form labels and standard UI labels.
  final TextStyle labelMD;

  // Chips, metadata, and compact helper labels.
  final TextStyle labelSM;

  // Ultra-compact labels used inside dense status UI.
  final TextStyle labelXS;

  // Compact captions that need stronger emphasis than body copy.
  final TextStyle captionMD;

  // Tiny metadata such as timestamps and counters.
  final TextStyle captionSM;

  // Tiny uppercase markers, badge text, and section kickers above headings.
  final TextStyle overline;

  @override
  AppTypography copyWith({
    TextStyle? displayXL,
    TextStyle? displayLG,
    TextStyle? headingXL,
    TextStyle? heading1,
    TextStyle? heading2,
    TextStyle? heading3,
    TextStyle? titleXL,
    TextStyle? titleLG,
    TextStyle? titleMD,
    TextStyle? titleSM,
    TextStyle? titleXS,
    TextStyle? bodyLG,
    TextStyle? bodyMD,
    TextStyle? bodyMDSemi,
    TextStyle? bodyBase,
    TextStyle? bodySM,
    TextStyle? bodyXS,
    TextStyle? labelLG,
    TextStyle? labelMD,
    TextStyle? labelSM,
    TextStyle? labelXS,
    TextStyle? captionMD,
    TextStyle? captionSM,
    TextStyle? overline,
  }) {
    return AppTypography(
      displayXL: displayXL ?? this.displayXL,
      displayLG: displayLG ?? this.displayLG,
      headingXL: headingXL ?? this.headingXL,
      heading1: heading1 ?? this.heading1,
      heading2: heading2 ?? this.heading2,
      heading3: heading3 ?? this.heading3,
      titleXL: titleXL ?? this.titleXL,
      titleLG: titleLG ?? this.titleLG,
      titleMD: titleMD ?? this.titleMD,
      titleSM: titleSM ?? this.titleSM,
      titleXS: titleXS ?? this.titleXS,
      bodyLG: bodyLG ?? this.bodyLG,
      bodyMD: bodyMD ?? this.bodyMD,
      bodyMDSemi: bodyMDSemi ?? this.bodyMDSemi,
      bodyBase: bodyBase ?? this.bodyBase,
      bodySM: bodySM ?? this.bodySM,
      bodyXS: bodyXS ?? this.bodyXS,
      labelLG: labelLG ?? this.labelLG,
      labelMD: labelMD ?? this.labelMD,
      labelSM: labelSM ?? this.labelSM,
      labelXS: labelXS ?? this.labelXS,
      captionMD: captionMD ?? this.captionMD,
      captionSM: captionSM ?? this.captionSM,
      overline: overline ?? this.overline,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;

    return AppTypography(
      displayXL: TextStyle.lerp(displayXL, other.displayXL, t) ?? displayXL,
      displayLG: TextStyle.lerp(displayLG, other.displayLG, t) ?? displayLG,
      headingXL: TextStyle.lerp(headingXL, other.headingXL, t) ?? headingXL,
      heading1: TextStyle.lerp(heading1, other.heading1, t) ?? heading1,
      heading2: TextStyle.lerp(heading2, other.heading2, t) ?? heading2,
      heading3: TextStyle.lerp(heading3, other.heading3, t) ?? heading3,
      titleXL: TextStyle.lerp(titleXL, other.titleXL, t) ?? titleXL,
      titleLG: TextStyle.lerp(titleLG, other.titleLG, t) ?? titleLG,
      titleMD: TextStyle.lerp(titleMD, other.titleMD, t) ?? titleMD,
      titleSM: TextStyle.lerp(titleSM, other.titleSM, t) ?? titleSM,
      titleXS: TextStyle.lerp(titleXS, other.titleXS, t) ?? titleXS,
      bodyLG: TextStyle.lerp(bodyLG, other.bodyLG, t) ?? bodyLG,
      bodyMD: TextStyle.lerp(bodyMD, other.bodyMD, t) ?? bodyMD,
      bodyMDSemi: TextStyle.lerp(bodyMDSemi, other.bodyMDSemi, t) ?? bodyMDSemi,
      bodyBase: TextStyle.lerp(bodyBase, other.bodyBase, t) ?? bodyBase,
      bodySM: TextStyle.lerp(bodySM, other.bodySM, t) ?? bodySM,
      bodyXS: TextStyle.lerp(bodyXS, other.bodyXS, t) ?? bodyXS,
      labelLG: TextStyle.lerp(labelLG, other.labelLG, t) ?? labelLG,
      labelMD: TextStyle.lerp(labelMD, other.labelMD, t) ?? labelMD,
      labelSM: TextStyle.lerp(labelSM, other.labelSM, t) ?? labelSM,
      labelXS: TextStyle.lerp(labelXS, other.labelXS, t) ?? labelXS,
      captionMD: TextStyle.lerp(captionMD, other.captionMD, t) ?? captionMD,
      captionSM: TextStyle.lerp(captionSM, other.captionSM, t) ?? captionSM,
      overline: TextStyle.lerp(overline, other.overline, t) ?? overline,
    );
  }
}

class AppTypographyTokens {
  AppTypographyTokens._();

  static final TextTheme baseTextTheme = GoogleFonts.plusJakartaSansTextTheme()
      .apply(bodyColor: AppColors.primary, displayColor: AppColors.primary);

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
    headingXL: _baseStyle(
      size: 44,
      weight: FontWeight.w900,
      height: 1,
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
    titleXL: _baseStyle(
      size: 28,
      weight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.4,
    ),
    titleLG: _baseStyle(size: 20, weight: FontWeight.w700, height: 1.2),
    titleMD: _baseStyle(size: 18, weight: FontWeight.w700, height: 1.2),
    titleSM: _baseStyle(size: 16, weight: FontWeight.w700, height: 1.25),
    titleXS: _baseStyle(size: 15, weight: FontWeight.w600, height: 1.3),
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
    bodyMDSemi: _baseStyle(
      size: 14,
      weight: FontWeight.w600,
      height: 1.45,
      color: AppColors.primary,
    ),
    bodyBase: _baseStyle(
      size: 13,
      weight: FontWeight.w500,
      height: 1.5,
      color: AppColors.mutedForeground,
    ),
    bodySM: _baseStyle(
      size: 12,
      weight: FontWeight.w500,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    bodyXS: _baseStyle(
      size: 11,
      weight: FontWeight.w500,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    labelLG: _baseStyle(size: 16, weight: FontWeight.w700, height: 1.2),
    labelMD: _baseStyle(size: 14, weight: FontWeight.w700, height: 1.2),
    labelSM: _baseStyle(size: 10, weight: FontWeight.w700, height: 1.2),
    labelXS: _baseStyle(size: 8, weight: FontWeight.w700, height: 1.2),
    captionMD: _baseStyle(
      size: 13,
      weight: FontWeight.w700,
      height: 1.25,
      color: AppColors.mutedForeground,
    ),
    captionSM: _baseStyle(
      size: 11,
      weight: FontWeight.w700,
      height: 1.25,
      color: AppColors.mutedForeground,
    ),
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
