import 'package:flutter/foundation.dart';

class GoogleMapViewOptions {
  const GoogleMapViewOptions({
    required this.mapId,
    required this.style,
    required this.shouldReapplyStyleOnWeb,
  });

  final String? mapId;
  final String? style;
  final bool shouldReapplyStyleOnWeb;

  static GoogleMapViewOptions resolve({
    required bool isWeb,
    required TargetPlatform platform,
    required String configuredWebMapId,
    required String configuredAndroidMapId,
    required String configuredIosMapId,
    required String? requestedStyle,
    required String fallbackStyle,
  }) {
    final rawStyle = (requestedStyle ?? fallbackStyle).trim();
    final style = rawStyle.isEmpty ? null : rawStyle;
    final rawMapId = _resolvePlatformMapId(
      isWeb: isWeb,
      platform: platform,
      configuredWebMapId: configuredWebMapId,
      configuredAndroidMapId: configuredAndroidMapId,
      configuredIosMapId: configuredIosMapId,
    );
    final mapId = rawMapId.isEmpty ? null : rawMapId;

    if (mapId != null) {
      return GoogleMapViewOptions(
        mapId: mapId,
        style: null,
        shouldReapplyStyleOnWeb: false,
      );
    }

    return GoogleMapViewOptions(
      mapId: null,
      style: style,
      shouldReapplyStyleOnWeb: isWeb && style != null,
    );
  }

  static String _resolvePlatformMapId({
    required bool isWeb,
    required TargetPlatform platform,
    required String configuredWebMapId,
    required String configuredAndroidMapId,
    required String configuredIosMapId,
  }) {
    if (isWeb) return configuredWebMapId.trim();

    switch (platform) {
      case TargetPlatform.android:
        return configuredAndroidMapId.trim();
      case TargetPlatform.iOS:
        return configuredIosMapId.trim();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return '';
    }
  }
}
