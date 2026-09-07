import 'package:flutter/foundation.dart';

/// Centralized app configuration.
/// All compile-time environment variables are read here.
///
/// Pass values at build time:
///   flutter run --dart-define-from-file=.env.json
///
/// Or individually:
///   flutter run --dart-define=API_HOST=localhost --dart-define=GOOGLE_WEB_CLIENT_ID=xxx
class AppConfig {
  AppConfig._();

  // ── API ──────────────────────────────────────────────
  static const String _apiHost = String.fromEnvironment('API_HOST');
  static const String apiScheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'http',
  );
  static const String _apiPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '3000',
  );

  static String get apiHost {
    return resolveApiHost();
  }

  static int? get apiPort {
    if (_apiPort.isEmpty) return null;
    return int.tryParse(_apiPort);
  }

  static Uri get apiUri {
    final port = apiPort;
    return Uri(scheme: apiScheme, host: apiHost, port: port, path: '/api');
  }

  static String get apiBaseUrl => apiUri.toString();

  // ── Public web links (deep links / share) ────────────
  /// Base URL used to build shareable links, e.g. `https://zentry.app`.
  /// Empty until a public web/deep-link host exists — shares fall back to
  /// text-only when unset.
  static const String shareBaseUrl = String.fromEnvironment('SHARE_BASE_URL');

  static Uri? shareLink(String path) {
    if (shareBaseUrl.isEmpty) return null;
    return Uri.parse(shareBaseUrl).resolve(path);
  }

  // ── Cloudinary assets ────────────────────────────────
  static const String cloudinaryImageBaseUrl = String.fromEnvironment(
    'CLOUDINARY_IMAGE_BASE_URL',
    defaultValue:
        'https://res.cloudinary.com/aashish1109/image/upload/zentry/mobile',
  );

  // ── Google OAuth ─────────────────────────────────────
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  // ── Google Maps ──────────────────────────────────────
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const String googleMapsWebMapId = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_MAP_ID',
  );
  static const String googleMapsAndroidMapId = String.fromEnvironment(
    'GOOGLE_MAPS_ANDROID_MAP_ID',
  );
  static const String googleMapsIosMapId = String.fromEnvironment(
    'GOOGLE_MAPS_IOS_MAP_ID',
  );

  // ── Mapbox ───────────────────────────────────────────
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const String mapboxStyleId = String.fromEnvironment(
    'MAPBOX_STYLE_ID',
    defaultValue: 'mapbox/streets-v12',
  );

  // ── Platform header for server ───────────────────────
  static String get clientPlatform {
    return resolveClientPlatform();
  }

  static String resolveApiHost({
    String configuredHost = _apiHost,
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final host = configuredHost.isNotEmpty ? configuredHost : 'localhost';
    final shouldUseAndroidEmulatorLoopback =
        !isWeb &&
        resolvedPlatform == TargetPlatform.android &&
        (host == 'localhost' || host == '127.0.0.1');

    if (shouldUseAndroidEmulatorLoopback) {
      return '10.0.2.2';
    }

    return host;
  }

  static String resolveClientPlatform({
    bool isWeb = kIsWeb,
    TargetPlatform? platform,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    if (isWeb) return 'web';
    if (resolvedPlatform == TargetPlatform.android) return 'android';
    if (resolvedPlatform == TargetPlatform.iOS) return 'ios';
    return 'web';
  }
}
