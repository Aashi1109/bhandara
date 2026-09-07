import 'package:flutter/material.dart';

import '../../../shared/theme/theme.dart';

class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    super.key,
    required this.palette,
    required this.selected,
    this.size = 42,
  });

  final AppPalette palette;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(size * 2 / 7),
        border: Border.all(
          color: selected ? palette.accent : context.appPalette.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size / 3,
            height: size / 3,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          Transform.translate(
            offset: Offset(-size / 21, 0),
            child: Container(
              width: size * 5 / 21,
              height: size * 5 / 21,
              decoration: BoxDecoration(
                color: palette.warning,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
