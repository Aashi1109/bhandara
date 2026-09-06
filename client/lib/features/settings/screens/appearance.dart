import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/providers/theme_preference.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_search_bar.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/header.dart';
import '../widgets/theme_preview_sheet.dart';
import '../widgets/theme_swatch.dart';
import './settings.dart';

class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  static const String routePath = '/settings/appearance';

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(themePreferenceProvider).value ?? 'system';
    final isBrandedTheme =
        selection != 'light' &&
        selection != 'dark' &&
        paletteById(selection) != null;
    final themes = appPalettes.where(_matchesQuery).toList();

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Appearance',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
              children: [
                Text('DISPLAY MODE', style: context.appTypography.overline),
                const SizedBox(height: 8),
                Text(
                  'Choose when light and dark appearances are used.',
                  style: context.appTypography.labelSMRegular.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                _DisplayModeControl(
                  selectedId:
                      selection == 'system' ||
                          selection == 'light' ||
                          selection == 'dark'
                      ? selection
                      : null,
                  onSelected: (id) => ref
                      .read(themePreferenceProvider.notifier)
                      .setPreference(id),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color themes',
                            style: context.appTypography.titleLG,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${appPalettes.length} themes · tap to preview',
                            style: context.appTypography.labelSMRegular
                                .copyWith(
                                  color: context.appPalette.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isBrandedTheme)
                      AppButton(
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        label: 'Clear',
                        onPressed: () => ref
                            .read(themePreferenceProvider.notifier)
                            .setPreference('system'),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                AppSearchBar(
                  controller: _searchController,
                  placeholder: 'Search themes',
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 12),
                if (themes.isEmpty)
                  _EmptySearch(query: _query)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.appPalette.surface,
                      border: Border.all(color: context.appPalette.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          for (var index = 0; index < themes.length; index++)
                            _ThemeListItem(
                              palette: themes[index],
                              selected: themes[index].id == selection,
                              showDivider: index != themes.length - 1,
                              onTap: () => _previewTheme(themes[index]),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesQuery(AppPalette palette) {
    if (_query.isEmpty) return true;
    return palette.label.toLowerCase().contains(_query.toLowerCase());
  }

  Future<void> _previewTheme(AppPalette palette) {
    return showThemePreviewSheet(
      context: context,
      palette: palette,
      onUse: () =>
          ref.read(themePreferenceProvider.notifier).setPreference(palette.id),
    );
  }
}

class _DisplayModeControl extends StatelessWidget {
  const _DisplayModeControl({
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('system', 'System', LucideIcons.smartphone),
      ('light', 'Light', LucideIcons.sun),
      ('dark', 'Dark', LucideIcons.moon),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appPalette.muted,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            Expanded(
              child: _DisplayModeOption(
                id: option.$1,
                label: option.$2,
                icon: option.$3,
                selected: selectedId == option.$1,
                onTap: onSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class _DisplayModeOption extends StatelessWidget {
  const _DisplayModeOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => onTap(id),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? context.appPalette.surface
                : context.appPalette.transparent,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(color: context.appPalette.border)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppIconSizes.xs),
              const SizedBox(width: 5),
              Text(label, style: context.appTypography.labelSM),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeListItem extends StatelessWidget {
  const _ThemeListItem({
    required this.palette,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} theme. Tap to preview.',
      child: Material(
        color: context.appPalette.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(bottom: BorderSide(color: context.appPalette.border))
                  : null,
            ),
            child: Row(
              children: [
                ThemeSwatch(palette: palette, selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(palette.label, style: context.appTypography.labelMD),
                      const SizedBox(height: 2),
                      Text(
                        selected ? 'Currently selected' : 'Tap to preview',
                        style: context.appTypography.labelSMRegular.copyWith(
                          color: context.appPalette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  size: AppIconSizes.m,
                  color: selected ? palette.accent : context.appPalette.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(LucideIcons.searchX, color: context.appPalette.mutedForeground),
          const SizedBox(height: 10),
          Text('No themes match “$query”', style: context.appTypography.bodyMD),
        ],
      ),
    );
  }
}
