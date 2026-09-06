import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';

Future<void> showThemePreviewSheet({
  required BuildContext context,
  required AppPalette palette,
  required VoidCallback onUse,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appPalette.surface,
    barrierColor: context.appPalette.primary.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.78,
      child: _ThemePreviewSheet(palette: palette, onUse: onUse),
    ),
  );
}

class _ThemePreviewSheet extends StatefulWidget {
  const _ThemePreviewSheet({required this.palette, required this.onUse});

  final AppPalette palette;
  final VoidCallback onUse;

  @override
  State<_ThemePreviewSheet> createState() => _ThemePreviewSheetState();
}

class _ThemePreviewSheetState extends State<_ThemePreviewSheet> {
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appPalette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        palette.label,
                        style: context.appTypography.heading3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _themeMood(palette.id),
                        style: context.appTypography.labelSMRegular.copyWith(
                          color: palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _LiveThemePreview(palette: palette)),
            const SizedBox(height: 12),
            _PaletteStrip(palette: palette),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    fullWidth: true,
                    size: AppButtonSize.md,
                    label: 'Use ${palette.label}',
                    onPressed: () {
                      widget.onUse();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: _favorite ? 'Remove favorite' : 'Save theme',
                  onPressed: () => setState(() => _favorite = !_favorite),
                  icon: Icon(
                    _favorite ? LucideIcons.heart : LucideIcons.heart,
                    color: _favorite
                        ? palette.accent
                        : context.appPalette.primary,
                    fill: _favorite ? 1 : 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveThemePreview extends StatelessWidget {
  const _LiveThemePreview({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: palette.accent,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SATURDAY · 6:30 PM',
                        style: context.appTypography.overline.copyWith(
                          color: palette.surface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Garden supper',
                        style: context.appTypography.heading3.copyWith(
                          color: palette.surface,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: palette.warning,
                  radius: 18,
                  child: Icon(
                    LucideIcons.utensils,
                    size: AppIconSizes.m,
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.muted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.image,
                          color: palette.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A long table, shared.',
                    style: context.appTypography.titleMD.copyWith(
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Seasonal plates and new neighbors in the courtyard.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTypography.labelSMRegular.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.warning,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Join the table',
                      textAlign: TextAlign.center,
                      style: context.appTypography.labelSM.copyWith(
                        color: palette.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = [
      palette.surface,
      palette.muted,
      palette.accent,
      palette.warning,
      palette.primary,
    ];

    return Row(
      children: [
        Text('PALETTE', style: context.appTypography.overline),
        const SizedBox(width: 10),
        for (final color in colors) ...[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: context.appPalette.border),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ],
    );
  }
}

String _themeMood(String id) {
  return switch (id) {
    'harvest-ember' => 'Warm · social · inviting',
    'garden-table' => 'Grounded · seasonal · generous',
    'tomato-social' => 'Bright · energetic · playful',
    'fresh-market' => 'Fresh · expressive · modern',
    'berry-bistro' => 'Cozy · rich · celebratory',
    'saffron-coast' => 'Sunny · balanced · relaxed',
    _ => 'A theme for every table',
  };
}
