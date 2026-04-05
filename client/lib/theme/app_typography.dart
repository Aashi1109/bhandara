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
    required this.heading3Strong,
    required this.heading3Heavy,
    required this.titleXL,
    required this.titleLG,
    required this.titleLGStrong,
    required this.titleMD,
    required this.titleMDStrong,
    required this.titleSM,
    required this.titleXS,
    required this.titleXSRegular,
    required this.titleXSStrong,
    required this.bodyLG,
    required this.bodyLGSemi,
    required this.bodyMD,
    required this.bodyMDStrong,
    required this.bodyMDSemi,
    required this.bodyBase,
    required this.bodyBaseSemi,
    required this.bodySM,
    required this.bodySMSemi,
    required this.bodySMStrong,
    required this.bodySMExtraBold,
    required this.bodyXS,
    required this.bodyXSStrong,
    required this.labelLG,
    required this.labelMD,
    required this.labelMDSemi,
    required this.labelSM,
    required this.labelSMStrong,
    required this.labelSMRegular,
    required this.labelXS,
    required this.labelXSStrong,
    required this.captionMD,
    required this.captionMDStrong,
    required this.captionSM,
    required this.captionSMStrong,
    required this.overline,
    required this.overlineEmphasis,
    required this.overlineStrong,
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

  // Same geometry as heading3, but a lighter weight for dense UIs.
  final TextStyle heading3Strong;

  // Same geometry as heading3, but the heaviest weight used in the app.
  final TextStyle heading3Heavy;

  // Large content titles below heading3 and above titleLG.
  final TextStyle titleXL;

  // Prominent content titles inside screens.
  final TextStyle titleLG;

  // Heavier 20px title used when titleLG needs more emphasis.
  final TextStyle titleLGStrong;

  // Standard titles in lists, cards, and dense layouts.
  final TextStyle titleMD;

  // Same geometry as titleMD, but heavier for dense sheet headers.
  final TextStyle titleMDStrong;

  // Compact item titles and tight UI blocks.
  final TextStyle titleSM;

  // Dense list rows and utility titles that are smaller than titleSM.
  final TextStyle titleXS;

  // 15px title used when titleXS needs a lighter weight.
  final TextStyle titleXSRegular;

  // 15px title used when titleXS needs stronger emphasis.
  final TextStyle titleXSStrong;

  // Emphasized body copy or lead-in text.
  final TextStyle bodyLG;

  // Emphasized 16px body copy with stronger weight.
  final TextStyle bodyLGSemi;

  // Default body copy for most readable content.
  final TextStyle bodyMD;

  // Stronger body copy for compact emphasis without jumping to title styles.
  final TextStyle bodyMDStrong;

  // Semibold body copy for emphasized rows without jumping to title styles.
  final TextStyle bodyMDSemi;

  // Transitional helper/body text used heavily across sheets and cards.
  final TextStyle bodyBase;

  // Stronger 13px helper/body text for compact emphasis.
  final TextStyle bodyBaseSemi;

  // Secondary, supporting, or helper copy.
  final TextStyle bodySM;

  // Semibold 12px supporting copy.
  final TextStyle bodySMSemi;

  // Stronger body copy for compact UI labels.
  final TextStyle bodySMStrong;

  // Strongest 12px body copy used for compact counters.
  final TextStyle bodySMExtraBold;

  // Tiny readable supporting copy such as timestamps.
  final TextStyle bodyXS;

  // Stronger tiny supporting copy for compact status text.
  final TextStyle bodyXSStrong;

  // Button text and high-emphasis control labels.
  final TextStyle labelLG;

  // Form labels and standard UI labels.
  final TextStyle labelMD;

  // Slightly softer 14px labels.
  final TextStyle labelMDSemi;

  // Chips, metadata, and compact helper labels.
  final TextStyle labelSM;

  // Heavier compact helper labels.
  final TextStyle labelSMStrong;

  // Same scale as labelSM, but lighter when labels need less emphasis.
  final TextStyle labelSMRegular;

  // Ultra-compact labels used inside dense status UI.
  final TextStyle labelXS;

  // Strongest compact label treatment for badges and tight counters.
  final TextStyle labelXSStrong;

  // Compact captions that need stronger emphasis than body copy.
  final TextStyle captionMD;

  // Stronger compact captions.
  final TextStyle captionMDStrong;

  // Tiny metadata such as timestamps and counters.
  final TextStyle captionSM;

  // Stronger tiny metadata treatment.
  final TextStyle captionSMStrong;

  // Tiny uppercase markers, badge text, and section kickers above headings.
  final TextStyle overline;

  // Tighter uppercase markers for dense system surfaces.
  final TextStyle overlineEmphasis;

  // Stronger uppercase markers used in profile/setup sections.
  final TextStyle overlineStrong;

  @override
  AppTypography copyWith({
    TextStyle? displayXL,
    TextStyle? displayLG,
    TextStyle? headingXL,
    TextStyle? heading1,
    TextStyle? heading2,
    TextStyle? heading3,
    TextStyle? heading3Strong,
    TextStyle? heading3Heavy,
    TextStyle? titleXL,
    TextStyle? titleLG,
    TextStyle? titleLGStrong,
    TextStyle? titleMD,
    TextStyle? titleMDStrong,
    TextStyle? titleSM,
    TextStyle? titleXS,
    TextStyle? titleXSRegular,
    TextStyle? titleXSStrong,
    TextStyle? bodyLG,
    TextStyle? bodyLGSemi,
    TextStyle? bodyMD,
    TextStyle? bodyMDStrong,
    TextStyle? bodyMDSemi,
    TextStyle? bodyBase,
    TextStyle? bodyBaseSemi,
    TextStyle? bodySM,
    TextStyle? bodySMSemi,
    TextStyle? bodySMStrong,
    TextStyle? bodySMExtraBold,
    TextStyle? bodyXS,
    TextStyle? bodyXSStrong,
    TextStyle? labelLG,
    TextStyle? labelMD,
    TextStyle? labelMDSemi,
    TextStyle? labelSM,
    TextStyle? labelSMStrong,
    TextStyle? labelSMRegular,
    TextStyle? labelXS,
    TextStyle? labelXSStrong,
    TextStyle? captionMD,
    TextStyle? captionMDStrong,
    TextStyle? captionSM,
    TextStyle? captionSMStrong,
    TextStyle? overline,
    TextStyle? overlineEmphasis,
    TextStyle? overlineStrong,
  }) {
    return AppTypography(
      displayXL: displayXL ?? this.displayXL,
      displayLG: displayLG ?? this.displayLG,
      headingXL: headingXL ?? this.headingXL,
      heading1: heading1 ?? this.heading1,
      heading2: heading2 ?? this.heading2,
      heading3: heading3 ?? this.heading3,
      heading3Strong: heading3Strong ?? this.heading3Strong,
      heading3Heavy: heading3Heavy ?? this.heading3Heavy,
      titleXL: titleXL ?? this.titleXL,
      titleLG: titleLG ?? this.titleLG,
      titleLGStrong: titleLGStrong ?? this.titleLGStrong,
      titleMD: titleMD ?? this.titleMD,
      titleMDStrong: titleMDStrong ?? this.titleMDStrong,
      titleSM: titleSM ?? this.titleSM,
      titleXS: titleXS ?? this.titleXS,
      titleXSRegular: titleXSRegular ?? this.titleXSRegular,
      titleXSStrong: titleXSStrong ?? this.titleXSStrong,
      bodyLG: bodyLG ?? this.bodyLG,
      bodyLGSemi: bodyLGSemi ?? this.bodyLGSemi,
      bodyMD: bodyMD ?? this.bodyMD,
      bodyMDStrong: bodyMDStrong ?? this.bodyMDStrong,
      bodyMDSemi: bodyMDSemi ?? this.bodyMDSemi,
      bodyBase: bodyBase ?? this.bodyBase,
      bodyBaseSemi: bodyBaseSemi ?? this.bodyBaseSemi,
      bodySM: bodySM ?? this.bodySM,
      bodySMSemi: bodySMSemi ?? this.bodySMSemi,
      bodySMStrong: bodySMStrong ?? this.bodySMStrong,
      bodySMExtraBold: bodySMExtraBold ?? this.bodySMExtraBold,
      bodyXS: bodyXS ?? this.bodyXS,
      bodyXSStrong: bodyXSStrong ?? this.bodyXSStrong,
      labelLG: labelLG ?? this.labelLG,
      labelMD: labelMD ?? this.labelMD,
      labelMDSemi: labelMDSemi ?? this.labelMDSemi,
      labelSM: labelSM ?? this.labelSM,
      labelSMStrong: labelSMStrong ?? this.labelSMStrong,
      labelSMRegular: labelSMRegular ?? this.labelSMRegular,
      labelXS: labelXS ?? this.labelXS,
      labelXSStrong: labelXSStrong ?? this.labelXSStrong,
      captionMD: captionMD ?? this.captionMD,
      captionMDStrong: captionMDStrong ?? this.captionMDStrong,
      captionSM: captionSM ?? this.captionSM,
      captionSMStrong: captionSMStrong ?? this.captionSMStrong,
      overline: overline ?? this.overline,
      overlineEmphasis: overlineEmphasis ?? this.overlineEmphasis,
      overlineStrong: overlineStrong ?? this.overlineStrong,
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
      heading3Strong:
          TextStyle.lerp(heading3Strong, other.heading3Strong, t) ??
          heading3Strong,
      heading3Heavy:
          TextStyle.lerp(heading3Heavy, other.heading3Heavy, t) ??
          heading3Heavy,
      titleXL: TextStyle.lerp(titleXL, other.titleXL, t) ?? titleXL,
      titleLG: TextStyle.lerp(titleLG, other.titleLG, t) ?? titleLG,
      titleLGStrong:
          TextStyle.lerp(titleLGStrong, other.titleLGStrong, t) ??
          titleLGStrong,
      titleMD: TextStyle.lerp(titleMD, other.titleMD, t) ?? titleMD,
      titleMDStrong:
          TextStyle.lerp(titleMDStrong, other.titleMDStrong, t) ??
          titleMDStrong,
      titleSM: TextStyle.lerp(titleSM, other.titleSM, t) ?? titleSM,
      titleXS: TextStyle.lerp(titleXS, other.titleXS, t) ?? titleXS,
      titleXSRegular:
          TextStyle.lerp(titleXSRegular, other.titleXSRegular, t) ??
          titleXSRegular,
      titleXSStrong:
          TextStyle.lerp(titleXSStrong, other.titleXSStrong, t) ??
          titleXSStrong,
      bodyLG: TextStyle.lerp(bodyLG, other.bodyLG, t) ?? bodyLG,
      bodyLGSemi: TextStyle.lerp(bodyLGSemi, other.bodyLGSemi, t) ?? bodyLGSemi,
      bodyMD: TextStyle.lerp(bodyMD, other.bodyMD, t) ?? bodyMD,
      bodyMDStrong:
          TextStyle.lerp(bodyMDStrong, other.bodyMDStrong, t) ?? bodyMDStrong,
      bodyMDSemi: TextStyle.lerp(bodyMDSemi, other.bodyMDSemi, t) ?? bodyMDSemi,
      bodyBase: TextStyle.lerp(bodyBase, other.bodyBase, t) ?? bodyBase,
      bodyBaseSemi:
          TextStyle.lerp(bodyBaseSemi, other.bodyBaseSemi, t) ?? bodyBaseSemi,
      bodySM: TextStyle.lerp(bodySM, other.bodySM, t) ?? bodySM,
      bodySMSemi: TextStyle.lerp(bodySMSemi, other.bodySMSemi, t) ?? bodySMSemi,
      bodySMStrong:
          TextStyle.lerp(bodySMStrong, other.bodySMStrong, t) ?? bodySMStrong,
      bodySMExtraBold:
          TextStyle.lerp(bodySMExtraBold, other.bodySMExtraBold, t) ??
          bodySMExtraBold,
      bodyXS: TextStyle.lerp(bodyXS, other.bodyXS, t) ?? bodyXS,
      bodyXSStrong:
          TextStyle.lerp(bodyXSStrong, other.bodyXSStrong, t) ?? bodyXSStrong,
      labelLG: TextStyle.lerp(labelLG, other.labelLG, t) ?? labelLG,
      labelMD: TextStyle.lerp(labelMD, other.labelMD, t) ?? labelMD,
      labelMDSemi:
          TextStyle.lerp(labelMDSemi, other.labelMDSemi, t) ?? labelMDSemi,
      labelSM: TextStyle.lerp(labelSM, other.labelSM, t) ?? labelSM,
      labelSMStrong:
          TextStyle.lerp(labelSMStrong, other.labelSMStrong, t) ??
          labelSMStrong,
      labelSMRegular:
          TextStyle.lerp(labelSMRegular, other.labelSMRegular, t) ??
          labelSMRegular,
      labelXS: TextStyle.lerp(labelXS, other.labelXS, t) ?? labelXS,
      labelXSStrong:
          TextStyle.lerp(labelXSStrong, other.labelXSStrong, t) ??
          labelXSStrong,
      captionMD: TextStyle.lerp(captionMD, other.captionMD, t) ?? captionMD,
      captionMDStrong:
          TextStyle.lerp(captionMDStrong, other.captionMDStrong, t) ??
          captionMDStrong,
      captionSM: TextStyle.lerp(captionSM, other.captionSM, t) ?? captionSM,
      captionSMStrong:
          TextStyle.lerp(captionSMStrong, other.captionSMStrong, t) ??
          captionSMStrong,
      overline: TextStyle.lerp(overline, other.overline, t) ?? overline,
      overlineEmphasis:
          TextStyle.lerp(overlineEmphasis, other.overlineEmphasis, t) ??
          overlineEmphasis,
      overlineStrong:
          TextStyle.lerp(overlineStrong, other.overlineStrong, t) ??
          overlineStrong,
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
    heading3Strong: _baseStyle(
      size: 24,
      weight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.5,
    ),
    heading3Heavy: _baseStyle(
      size: 24,
      weight: FontWeight.w900,
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
    titleLGStrong: _baseStyle(size: 20, weight: FontWeight.w800, height: 1.2),
    titleMD: _baseStyle(size: 18, weight: FontWeight.w700, height: 1.2),
    titleMDStrong: _baseStyle(size: 18, weight: FontWeight.w800, height: 1.2),
    titleSM: _baseStyle(size: 16, weight: FontWeight.w700, height: 1.25),
    titleXS: _baseStyle(size: 15, weight: FontWeight.w600, height: 1.3),
    titleXSRegular: _baseStyle(size: 15, weight: FontWeight.w500, height: 1.25),
    titleXSStrong: _baseStyle(size: 15, weight: FontWeight.w700, height: 1.3),
    bodyLG: _baseStyle(
      size: 16,
      weight: FontWeight.w500,
      height: 1.5,
      color: AppColors.mutedForeground,
    ),
    bodyLGSemi: _baseStyle(
      size: 16,
      weight: FontWeight.w600,
      height: 1.5,
      color: AppColors.primary,
    ),
    bodyMD: _baseStyle(
      size: 14,
      weight: FontWeight.w500,
      height: 1.5,
      color: AppColors.primary,
    ),
    bodyMDStrong: _baseStyle(
      size: 14,
      weight: FontWeight.w700,
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
    bodyBaseSemi: _baseStyle(
      size: 13,
      weight: FontWeight.w600,
      height: 1.5,
      color: AppColors.mutedForeground,
    ),
    bodySM: _baseStyle(
      size: 12,
      weight: FontWeight.w500,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    bodySMSemi: _baseStyle(
      size: 12,
      weight: FontWeight.w600,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    bodySMStrong: _baseStyle(
      size: 12,
      weight: FontWeight.w700,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    bodySMExtraBold: _baseStyle(
      size: 12,
      weight: FontWeight.w800,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    bodyXS: _baseStyle(
      size: 11,
      weight: FontWeight.w500,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    bodyXSStrong: _baseStyle(
      size: 11,
      weight: FontWeight.w800,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
    labelLG: _baseStyle(size: 16, weight: FontWeight.w700, height: 1.2),
    labelMD: _baseStyle(size: 14, weight: FontWeight.w700, height: 1.2),
    labelMDSemi: _baseStyle(size: 14, weight: FontWeight.w600, height: 1.2),
    labelSM: _baseStyle(size: 10, weight: FontWeight.w700, height: 1.2),
    labelSMStrong: _baseStyle(size: 10, weight: FontWeight.w800, height: 1.2),
    labelSMRegular: _baseStyle(size: 10, weight: FontWeight.w500, height: 1.2),
    labelXS: _baseStyle(size: 8, weight: FontWeight.w700, height: 1.2),
    labelXSStrong: _baseStyle(
      size: 8,
      weight: FontWeight.w900,
      height: 1.2,
      letterSpacing: 1.5,
    ),
    captionMD: _baseStyle(
      size: 13,
      weight: FontWeight.w700,
      height: 1.25,
      color: AppColors.mutedForeground,
    ),
    captionMDStrong: _baseStyle(
      size: 13,
      weight: FontWeight.w800,
      height: 1.25,
      color: AppColors.mutedForeground,
    ),
    captionSM: _baseStyle(
      size: 11,
      weight: FontWeight.w700,
      height: 1.25,
      color: AppColors.mutedForeground,
    ),
    captionSMStrong: _baseStyle(
      size: 11,
      weight: FontWeight.w800,
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
    overlineEmphasis: _baseStyle(
      size: 10,
      weight: FontWeight.w800,
      height: 1.2,
      letterSpacing: 1.4,
      color: AppColors.mutedForeground,
    ),
    overlineStrong: _baseStyle(
      size: 10,
      weight: FontWeight.w900,
      height: 1.2,
      letterSpacing: 2,
      color: AppColors.mutedForeground,
    ),
  );

  static TextStyle get serifFont =>
      GoogleFonts.playfairDisplay(color: AppColors.primary);
}
