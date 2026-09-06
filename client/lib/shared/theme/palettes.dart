import 'package:flutter/material.dart';

import './app_palette.dart';

const AppPalette lightPalette = AppPalette(
  id: 'light',
  label: 'Light',
  brightness: Brightness.light,
  surface: Color(0xFFFFFFFF),
  muted: Color(0xFFF3F4F6),
  primary: Color(0xFF000000),
  mutedForeground: Color(0xFF6B7280),
  border: Color(0xFFE5E7EB),
  accent: Color(0xFF10B981),
  error: Color(0xFFEF4444),
  success: Color(0xFF10B981),
  warning: Color(0xFFF59E0B),
  badgeFirstEventBackground: Color(0xFFFCF5E1),
  badgeConversationStarterBackground: Color(0xFFEAF6F1),
  badgeCommunitySupporterBackground: Color(0xFFF2E8D5),
  badgeWeekStreakBackground: Color(0xFFF7F1DF),
  transparent: Colors.transparent,
);

const AppPalette darkPalette = AppPalette(
  id: 'dark',
  label: 'Dark',
  brightness: Brightness.dark,
  surface: Color(0xFF0B0B0C),
  muted: Color(0xFF1A1B1E),
  primary: Color(0xFFFFFFFF),
  mutedForeground: Color(0xFF9CA3AF),
  border: Color(0xFF2A2C31),
  accent: Color(0xFF34D399),
  error: Color(0xFFF87171),
  success: Color(0xFF34D399),
  warning: Color(0xFFFBBF24),
  badgeFirstEventBackground: Color(0xFF2E2717),
  badgeConversationStarterBackground: Color(0xFF14271F),
  badgeCommunitySupporterBackground: Color(0xFF2B2418),
  badgeWeekStreakBackground: Color(0xFF2A2618),
  transparent: Colors.transparent,
);

const AppPalette harvestEmberPalette = AppPalette(
  id: 'harvest-ember',
  label: 'Harvest Ember',
  brightness: Brightness.light,
  surface: Color(0xFFFFF8EF),
  muted: Color(0xFFF8DDD6),
  primary: Color(0xFF2F241D),
  mutedForeground: Color(0xFF75685D),
  border: Color(0xFFEADDD0),
  accent: Color(0xFFD94F3D),
  error: Color(0xFFB42318),
  success: Color(0xFF176B67),
  warning: Color(0xFFF2B84B),
  badgeFirstEventBackground: Color(0xFFFFEBC2),
  badgeConversationStarterBackground: Color(0xFFDCEDEA),
  badgeCommunitySupporterBackground: Color(0xFFF8DDD6),
  badgeWeekStreakBackground: Color(0xFFFFE7B0),
  transparent: Colors.transparent,
);

const AppPalette gardenTablePalette = AppPalette(
  id: 'garden-table',
  label: 'Garden Table',
  brightness: Brightness.light,
  surface: Color(0xFFF5F7ED),
  muted: Color(0xFFE1E8CF),
  primary: Color(0xFF27351F),
  mutedForeground: Color(0xFF66705D),
  border: Color(0xFFD5DDC2),
  accent: Color(0xFF5F7A3D),
  error: Color(0xFFB5472B),
  success: Color(0xFF5F7A3D),
  warning: Color(0xFFD7A63C),
  badgeFirstEventBackground: Color(0xFFF3E5B8),
  badgeConversationStarterBackground: Color(0xFFDDE9D2),
  badgeCommunitySupporterBackground: Color(0xFFE8DFC8),
  badgeWeekStreakBackground: Color(0xFFF1E7BD),
  transparent: Colors.transparent,
);

const AppPalette tomatoSocialPalette = AppPalette(
  id: 'tomato-social',
  label: 'Tomato Social',
  brightness: Brightness.light,
  surface: Color(0xFFFFF7F2),
  muted: Color(0xFFFFE0D6),
  primary: Color(0xFF35201C),
  mutedForeground: Color(0xFF78615B),
  border: Color(0xFFF0D7CF),
  accent: Color(0xFFF04438),
  error: Color(0xFFC4322A),
  success: Color(0xFF16866F),
  warning: Color(0xFFFFB000),
  badgeFirstEventBackground: Color(0xFFFFE6B2),
  badgeConversationStarterBackground: Color(0xFFD9EEE9),
  badgeCommunitySupporterBackground: Color(0xFFFFDDD3),
  badgeWeekStreakBackground: Color(0xFFFFE9BA),
  transparent: Colors.transparent,
);

const AppPalette freshMarketPalette = AppPalette(
  id: 'fresh-market',
  label: 'Fresh Market',
  brightness: Brightness.light,
  surface: Color(0xFFF2FBF9),
  muted: Color(0xFFCFF3EA),
  primary: Color(0xFF173A37),
  mutedForeground: Color(0xFF58726E),
  border: Color(0xFFCBE4DF),
  accent: Color(0xFF00A88F),
  error: Color(0xFFB3265E),
  success: Color(0xFF008A75),
  warning: Color(0xFFE0A21A),
  badgeFirstEventBackground: Color(0xFFFFE8B8),
  badgeConversationStarterBackground: Color(0xFFCFF3EA),
  badgeCommunitySupporterBackground: Color(0xFFF2DCE8),
  badgeWeekStreakBackground: Color(0xFFFFEDC7),
  transparent: Colors.transparent,
);

const AppPalette berryBistroPalette = AppPalette(
  id: 'berry-bistro',
  label: 'Berry Bistro',
  brightness: Brightness.light,
  surface: Color(0xFFFFF7FA),
  muted: Color(0xFFF8DCE7),
  primary: Color(0xFF3A1D2A),
  mutedForeground: Color(0xFF765B67),
  border: Color(0xFFECD4DE),
  accent: Color(0xFFB3265E),
  error: Color(0xFFB42318),
  success: Color(0xFF347A67),
  warning: Color(0xFFF2A900),
  badgeFirstEventBackground: Color(0xFFFFE7AE),
  badgeConversationStarterBackground: Color(0xFFDDECE6),
  badgeCommunitySupporterBackground: Color(0xFFF8DCE7),
  badgeWeekStreakBackground: Color(0xFFFFE9B8),
  transparent: Colors.transparent,
);

const AppPalette saffronCoastPalette = AppPalette(
  id: 'saffron-coast',
  label: 'Saffron Coast',
  brightness: Brightness.light,
  surface: Color(0xFFFFFAEE),
  muted: Color(0xFFFDE7B2),
  primary: Color(0xFF3B2A13),
  mutedForeground: Color(0xFF7A6548),
  border: Color(0xFFE9D9B8),
  accent: Color(0xFFD97706),
  error: Color(0xFFC65332),
  success: Color(0xFF0F766E),
  warning: Color(0xFFF2B84B),
  badgeFirstEventBackground: Color(0xFFFDE7B2),
  badgeConversationStarterBackground: Color(0xFFDCEDEA),
  badgeCommunitySupporterBackground: Color(0xFFF1DFC5),
  badgeWeekStreakBackground: Color(0xFFFFE8AE),
  transparent: Colors.transparent,
);

const List<AppPalette> appPalettes = [
  harvestEmberPalette,
  gardenTablePalette,
  tomatoSocialPalette,
  freshMarketPalette,
  berryBistroPalette,
  saffronCoastPalette,
];

AppPalette? paletteById(String id) {
  if (id == lightPalette.id) return lightPalette;
  if (id == darkPalette.id) return darkPalette;

  for (final palette in appPalettes) {
    if (palette.id == id) return palette;
  }
  return null;
}
