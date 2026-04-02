import 'dart:io' show Platform;

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
    final host = _apiHost.isNotEmpty ? _apiHost : 'localhost';
    if (Platform.isAndroid &&
        (host == 'localhost' || host == '127.0.0.1')) {
      return '10.0.2.2';
    }
    return host;
  }

  static int? get apiPort {
    if (_apiPort.isEmpty) return null;
    return int.tryParse(_apiPort);
  }

  static Uri get apiUri {
    final port = apiPort;
    return Uri(
      scheme: apiScheme,
      host: apiHost,
      port: port,
      path: '/api',
    );
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
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }
}
