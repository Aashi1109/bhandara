import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../config.dart';
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
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-client-platform': AppConfig.clientPlatform,
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
          debugPrint('=== DIO ERROR: ${error.requestOptions.path} status=${error.response?.statusCode} msg=${error.message} ===');
          if (await _shouldRedirectToLogin(error)) {
            await _handleUnauthorized();
          }
          return handler.next(error);
        },
      ),
    );

    // Add interceptors for logging
    _dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
  }

  late final Dio _dio;
  final _storage = SecureStorage(namespace: 'auth');
  static const String _tokenKey = 'token';
  bool _isHandlingUnauthorized = false;
  Future<void> Function()? onUnauthorized;

  Future<bool> _shouldRedirectToLogin(DioException error) async {
    final response = error.response;
    final statusCode = response?.statusCode;
    final path = error.requestOptions.path;

    if (_isHandlingUnauthorized) {
      return false;
    }

    if (_isAuthEndpoint(path)) {
      return false;
    }

    if (statusCode == 401) {
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
    debugPrint('=== UNAUTHORIZED TRIGGERED ===');
    debugPrint('Stack: ${StackTrace.current}');
    try {
      await _storage.delete(_tokenKey);
      await onUnauthorized?.call();

      final location = router.routeInformationProvider.value.uri.path;
      final isAlreadyInPublicAuthFlow =
          location == SplashScreen.routePath ||
          location == AuthScreen.routePath ||
          location == LoginScreen.routePath ||
          location == OnboardingScreen.routePath;

      debugPrint('=== UNAUTHORIZED: location=$location redirecting=${!isAlreadyInPublicAuthFlow} ===');
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
