import 'package:dio/dio.dart';
import 'dart:io' show Platform;
import 'secure_storage.dart';

class ApiService {
  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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
  static const String _configuredHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'brave-wren-big.ngrok-free.app',
  );

  static const String _configuredScheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'https',
  );
  static const String _configuredPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '',
  );

  static String get host {
    if (_configuredHost.isNotEmpty) {
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
      return Uri(
        scheme: _configuredScheme,
        host: host,
        path: '/api',
      );
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

  Dio get dio => _dio;
}

final apiService = ApiService();
