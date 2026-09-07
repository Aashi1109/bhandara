import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/theme.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.name,
    this.imageUrl,
    required this.size,
    required this.textSize,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
    this.textColor,
    this.imageBuilder,
  });

  final String? name;
  final String? imageUrl;
  final double size;
  final double textSize;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget Function(BuildContext context, Widget child)? imageBuilder;

  String get _initial {
    final value = name?.trim();
    if (value == null || value.isEmpty) return 'U';
    return value[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        this.backgroundColor ?? context.appPalette.muted;
    final textColor = this.textColor ?? context.appPalette.primary;
    final normalizedImageUrl = imageUrl?.trim();
    final Widget child;
    if (normalizedImageUrl == null || normalizedImageUrl.isEmpty) {
      child = _fallback(context, backgroundColor, textColor);
    } else {
      child = CachedNetworkImage(
        imageUrl: normalizedImageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: backgroundColor),
        errorWidget: (_, _, _) =>
            _fallback(context, backgroundColor, textColor),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor == null || borderWidth <= 0
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: ClipOval(
        child: imageBuilder == null ? child : imageBuilder!(context, child),
      ),
    );
  }

  Widget _fallback(
    BuildContext context,
    Color backgroundColor,
    Color textColor,
  ) {
    final typography = context.appTypography;
    final style = switch (textSize) {
      >= 18 => typography.titleMD,
      >= 16 => typography.titleSM,
      >= 14 => typography.bodyMDSemi,
      _ => typography.bodyBase,
    };

    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(_initial, style: style.copyWith(color: textColor)),
    );
  }
}
