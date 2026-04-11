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

  // ── Google OAuth ─────────────────────────────────────
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  // ── Google Maps ──────────────────────────────────────
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
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
