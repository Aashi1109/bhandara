import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../shared/constants/api.dart';
import '../../profile/models/user.dart';
import '../../../shared/services/api.dart';
import '../../../shared/services/base.dart';
import '../../../shared/services/secure_storage.dart';

class AuthService extends BaseService {
  final Dio _dio = apiService.dio;
  final _storage = SecureStorage(namespace: 'auth');
  static const String _tokenKey = 'token';

  Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post(
        Api.login,
        data: {'email': email, 'password': password},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final session = data['session'] as Map<String, dynamic>?;
      if (session != null && session['id'] != null) {
        await _storage.write(_tokenKey, session['id'] as String);
      }
      final userData = data['user'] ?? data;
      return User.fromJson(userData as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Login failed');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> signup(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(Api.signup, data: data);
      final responseData = response.data['data'];
      if (responseData != null && responseData['session'] != null) {
        await _storage.write(
          _tokenKey,
          responseData['session']['id'] as String,
        );
      }
      final json = responseData as Map<String, dynamic>;
      final userData = json['user'] ?? json;
      return User.fromJson(userData as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Signup failed');
    } catch (e) {
      rethrow;
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

  Future<User> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );
      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Failed to retrieve Google ID Token');
      }
      final response = await _dio.post(
        Api.googleSignIn,
        data: {'token': googleAuth.idToken},
      );
      final data = response.data['data'];
      if (data != null &&
          data['session'] != null &&
          data['session']['id'] != null) {
        await _storage.write(_tokenKey, data['session']['id'] as String);
      }
      final json = data as Map<String, dynamic>;
      final userData = json['user'] ?? json;
      return User.fromJson(userData as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Google Sign-In failed');
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> getSession() async {
    try {
      final response = await _dio.get(Api.session);
      final json = response.data['data'] as Map<String, dynamic>;
      final userData = json['user'] ?? json;
      return User.fromJson(userData as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch session');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _dio.post(Api.forgotPassword, data: {'email': email});
    } on DioException catch (e) {
      throwError(e, 'Failed to send reset email');
    } catch (e) {
      rethrow;
    }
  }

  Future<String> verifyPasswordResetOTP(String email, String code) async {
    try {
      final response = await _dio.post(
        Api.verifyResetOTP,
        data: {'email': email, 'code': code},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      return data?['token'] as String? ?? '';
    } on DioException catch (e) {
      throwError(e, 'Invalid or expired code');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        Api.resetPassword,
        data: {'token': token, 'email': email, 'password': newPassword},
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to reset password');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getSessions() async {
    try {
      final response = await _dio.get(Api.sessions);
      return response.data['data'] as List? ?? [];
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch sessions');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _dio.delete(Api.deleteSession(sessionId));
    } on DioException catch (e) {
      throwError(e, 'Failed to delete session');
    } catch (e) {
      rethrow;
    }
  }
}

final authService = AuthService();
