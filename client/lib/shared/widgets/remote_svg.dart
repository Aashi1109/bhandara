import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';

class AppRemoteSvg extends StatelessWidget {
  const AppRemoteSvg({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.semanticsLabel,
    this.fallbackIcon = Icons.image_outlined,
    this.enabled = true,
  });

  final String url;
  final double width;
  final double height;
  final String semanticsLabel;
  final IconData fallbackIcon;
  final bool enabled;

  static bool isSvgSource(String sourceUrl) {
    return Uri.tryParse(sourceUrl)?.path.toLowerCase().endsWith('.svg') ?? false;
  }

  static String renderableUrl(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.host != 'res.cloudinary.com' ||
        !uri.path.endsWith('.svg') ||
        !uri.path.contains('/image/upload/')) {
      return sourceUrl;
    }

    return uri
        .replace(
          path: uri.path.replaceFirst(
            '/image/upload/',
            '/image/upload/e_trim,f_png/',
          ),
        )
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback(context);
    if (!enabled || url.isEmpty) return fallback;

    if (url.startsWith('assets/')) {
      if (isSvgSource(url)) {
        return SvgPicture.asset(
          url,
          width: width,
          height: height,
          fit: BoxFit.contain,
          semanticsLabel: semanticsLabel,
          errorBuilder: (_, _, _) => fallback,
        );
      }

      return Image.asset(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        semanticLabel: semanticsLabel,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    final resolvedUrl = renderableUrl(url);
    if (resolvedUrl != url) {
      return Image.network(
        resolvedUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        semanticLabel: semanticsLabel,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(context),
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return SvgPicture.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: semanticsLabel,
      placeholderBuilder: (_) => _placeholder(context),
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _placeholder(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.appPalette.primary,
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: AppIconSizes.xl,
          color: context.appPalette.mutedForeground,
        ),
      ),
    );
  }
}
