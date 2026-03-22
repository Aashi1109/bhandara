import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../router.dart';
import '../constants/api.dart' as api_constants;
import '../screens/auth.dart';
import '../screens/login.dart';
import '../screens/onboarding.dart';
import '../screens/splash.dart';
import 'secure_storage.dart';

class ApiService {
  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 360),
        receiveTimeout: const Duration(seconds: 360),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auth Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(_tokenKey);
          if (token != null) {
            options.headers['Cookie'] = 'bh_session=$token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (await _shouldRedirectToLogin(error)) {
            await _handleUnauthorized();
          }
          return handler.next(error);
        },
      ),
    );

    // Add interceptors for logging
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
  }

  late final Dio _dio;
  final _storage = SecureStorage(namespace: 'auth');
  static const String _tokenKey = 'token';
  bool _isHandlingUnauthorized = false;
  Future<void> Function()? onUnauthorized;
  static const String _configuredHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static const String _configuredScheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'http',
  );
  static const String _configuredPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '3000',
  );

  static String get host {
    if (_configuredHost.isNotEmpty) {
      if (Platform.isAndroid &&
          (_configuredHost == 'localhost' || _configuredHost == '127.0.0.1')) {
        return '10.0.2.2';
      }
      return _configuredHost;
    }
    if (Platform.isAndroid) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static int? get port {
    if (_configuredPort.isEmpty) {
      return null;
    }

    return int.tryParse(_configuredPort);
  }

  static Uri get apiUri {
    final configuredPort = port;
    if (configuredPort == null) {
      return Uri(scheme: _configuredScheme, host: host, path: '/api');
    }

    return Uri(
      scheme: _configuredScheme,
      host: host,
      port: configuredPort,
      path: '/api',
    );
  }

  static String get baseUrl {
    return apiUri.toString();
  }

  Future<bool> _shouldRedirectToLogin(DioException error) async {
    final response = error.response;
    final statusCode = response?.statusCode;
    final path = error.requestOptions.path;
    final token = await _storage.read(_tokenKey);

    if (token == null || token.isEmpty) {
      return false;
    }

    if (_isHandlingUnauthorized) {
      return false;
    }

    if (_isAuthEndpoint(path)) {
      return false;
    }

    if (statusCode == 401 || statusCode == 403) {
      return true;
    }

    final errorMessage = _extractErrorMessage(response?.data);
    if (errorMessage == null) {
      return false;
    }

    final normalized = errorMessage.toLowerCase();
    return normalized.contains('session not found') ||
        normalized.contains('unauthorized') ||
        normalized.contains('not authorized') ||
        normalized.contains('forbidden');
  }

  bool _isAuthEndpoint(String path) {
    return path == api_constants.Api.login ||
        path == api_constants.Api.signup ||
        path == api_constants.Api.logout ||
        path == api_constants.Api.googleSignIn ||
        path == api_constants.Api.session;
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is String) {
        return error;
      }
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    }

    return null;
  }

  Future<void> _handleUnauthorized() async {
    _isHandlingUnauthorized = true;
    try {
      await _storage.delete(_tokenKey);
      await onUnauthorized?.call();

      final location = router.routeInformationProvider.value.uri.path;
      final isAlreadyInPublicAuthFlow =
          location == SplashScreen.routePath ||
          location == AuthScreen.routePath ||
          location == LoginScreen.routePath ||
          location == OnboardingScreen.routePath;

      if (!isAlreadyInPublicAuthFlow) {
        router.go(AuthScreen.routePath);
      }
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  Dio get dio => _dio;
}

final apiService = ApiService();
