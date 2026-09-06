import 'package:flutter/material.dart';

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.id,
    required this.label,
    required this.brightness,
    required this.surface,
    required this.muted,
    required this.primary,
    required this.mutedForeground,
    required this.border,
    required this.accent,
    required this.error,
    required this.success,
    required this.warning,
    required this.badgeFirstEventBackground,
    required this.badgeConversationStarterBackground,
    required this.badgeCommunitySupporterBackground,
    required this.badgeWeekStreakBackground,
    required this.transparent,
  });

  final String id;
  final String label;
  final Brightness brightness;
  final Color surface;
  final Color muted;
  final Color primary;
  final Color mutedForeground;
  final Color border;
  final Color accent;
  final Color error;
  final Color success;
  final Color warning;
  final Color badgeFirstEventBackground;
  final Color badgeConversationStarterBackground;
  final Color badgeCommunitySupporterBackground;
  final Color badgeWeekStreakBackground;
  final Color transparent;

  @override
  AppPalette copyWith({
    String? id,
    String? label,
    Brightness? brightness,
    Color? surface,
    Color? muted,
    Color? primary,
    Color? mutedForeground,
    Color? border,
    Color? accent,
    Color? error,
    Color? success,
    Color? warning,
    Color? badgeFirstEventBackground,
    Color? badgeConversationStarterBackground,
    Color? badgeCommunitySupporterBackground,
    Color? badgeWeekStreakBackground,
    Color? transparent,
  }) {
    return AppPalette(
      id: id ?? this.id,
      label: label ?? this.label,
      brightness: brightness ?? this.brightness,
      surface: surface ?? this.surface,
      muted: muted ?? this.muted,
      primary: primary ?? this.primary,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      badgeFirstEventBackground:
          badgeFirstEventBackground ?? this.badgeFirstEventBackground,
      badgeConversationStarterBackground:
          badgeConversationStarterBackground ??
          this.badgeConversationStarterBackground,
      badgeCommunitySupporterBackground:
          badgeCommunitySupporterBackground ??
          this.badgeCommunitySupporterBackground,
      badgeWeekStreakBackground:
          badgeWeekStreakBackground ?? this.badgeWeekStreakBackground,
      transparent: transparent ?? this.transparent,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;

    return AppPalette(
      id: t < 0.5 ? id : other.id,
      label: t < 0.5 ? label : other.label,
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      mutedForeground:
          Color.lerp(mutedForeground, other.mutedForeground, t) ??
          mutedForeground,
      border: Color.lerp(border, other.border, t) ?? border,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      error: Color.lerp(error, other.error, t) ?? error,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      badgeFirstEventBackground:
          Color.lerp(
            badgeFirstEventBackground,
            other.badgeFirstEventBackground,
            t,
          ) ??
          badgeFirstEventBackground,
      badgeConversationStarterBackground:
          Color.lerp(
            badgeConversationStarterBackground,
            other.badgeConversationStarterBackground,
            t,
          ) ??
          badgeConversationStarterBackground,
      badgeCommunitySupporterBackground:
          Color.lerp(
            badgeCommunitySupporterBackground,
            other.badgeCommunitySupporterBackground,
            t,
          ) ??
          badgeCommunitySupporterBackground,
      badgeWeekStreakBackground:
          Color.lerp(
            badgeWeekStreakBackground,
            other.badgeWeekStreakBackground,
            t,
          ) ??
          badgeWeekStreakBackground,
      transparent: Color.lerp(transparent, other.transparent, t) ?? transparent,
    );
  }
}
