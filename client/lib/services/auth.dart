import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import 'secure_storage.dart';
import '../models/api_response.dart';
import '../models/user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final Dio _dio = apiService.dio;
  final _storage = SecureStorage(namespace: 'auth');
  static const String _tokenKey =
      'token'; // Prefix will be added by SecureStorage

  Future<ApiResponse<User>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        Api.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data['data'];
      if (data != null && data['token'] != null) {
        await _storage.write(_tokenKey, data['token'] as String);
      }

      return ApiResponse.fromJson(response.data, (json) {
        final userData = (json as Map<String, dynamic>)['user'] ?? json;
        return User.fromJson(userData as Map<String, dynamic>);
      });
    } on DioException catch (e) {
      return ApiResponse(error: e.response?.data['error'] ?? 'Login failed');
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<ApiResponse<User>> signup(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(Api.signup, data: data);

      final responseData = response.data['data'];
      if (responseData != null && responseData['token'] != null) {
        await _storage.write(_tokenKey, responseData['token'] as String);
      }

      return ApiResponse.fromJson(response.data, (json) {
        final userData = (json as Map<String, dynamic>)['user'] ?? json;
        return User.fromJson(userData as Map<String, dynamic>);
      });
    } on DioException catch (e) {
      return ApiResponse(error: e.response?.data['error'] ?? 'Signup failed');
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.get(Api.logout);
    } catch (e) {
      // Ignore logout errors
    } finally {
      await _storage.delete(_tokenKey);
    }
  }

  Future<ApiResponse<User>> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        return ApiResponse(error: 'Failed to retrieve Google ID Token');
      }

      final response = await _dio.post(
        Api.googleSignIn,
        data: {'token': googleAuth.idToken},
      );

      final data = response.data['data'];
      if (data != null) {
        // The backend explicitly returns { data: null, success: true }
        // But in signInWithIdToken some parts suggest it returns session/user
        // We'll write to storage if a token exists.
        if (data['session'] != null && data['session']['id'] != null) {
          await _storage.write(_tokenKey, data['session']['id'] as String);
        }
      }

      return ApiResponse.fromJson(response.data, (json) {
        final userData = (json as Map<String, dynamic>)['user'] ?? json;
        return User.fromJson(userData as Map<String, dynamic>);
      });
    } on DioException catch (e) {
      return ApiResponse(
        error: e.response?.data['error'] ?? 'Google Sign-In failed',
      );
    } catch (e) {
      return ApiResponse(
        error: 'An unexpected error occurred during Google Sign-In',
      );
    }
  }
}

final authService = AuthService();
