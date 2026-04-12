import 'package:dio/dio.dart';
import '../../../shared/constants/api.dart';
import '../../../shared/services/api.dart';
import '../models/achievement.dart';
import '../../../shared/models/api_response.dart';
import '../../events/models/event.dart';
import '../models/user.dart';
import '../../../shared/services/base.dart';

class UserService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<User?> getCurrentUser() async {
    try {
      final response = await _dio.get(Api.session);
      final json = response.data['data'] as Map<String, dynamic>;
      return User.fromJson(json['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch user');
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> getUserById(String id) async {
    try {
      final response = await _dio.get(Api.getUserById(id));
      final json = response.data['data'] as Map<String, dynamic>;
      return User.fromJson(json);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch user');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateUser(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(Api.updateUser(id), data: data);
      final json = response.data['data'] as Map<String, dynamic>;
      return User.fromJson(json);
    } on DioException catch (e) {
      throwError(e, 'Failed to update profile');
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginatedResponse<User>> getByQuery({
    String? email,
    String? username,
  }) async {
    try {
      final response = await _dio.get(
        Api.getUserByQuery,
        queryParameters: {
          ...email != null ? {'email': email} : {},
          ...username != null ? {'username': username} : {},
        },
      );
      return PaginatedResponse<User>.fromJson(
        response.data['data'] as Map<String, dynamic>,
        (json) => User.fromJson(json! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch user');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Tag>> getUserInterests(String userId) async {
    try {
      final response = await _dio.get(Api.userInterests(userId));
      final data = response.data['data'] as List? ?? [];
      return data
          .whereType<Map>()
          .map((json) => Tag.fromJson(json.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch user interests');
    } catch (e) {
      rethrow;
    }
  }

  Future<UserSettings?> getSettings(String userId) async {
    try {
      final response = await _dio.get(Api.userSettings(userId));
      final json = response.data['data'] as Map<String, dynamic>;
      return UserSettings.fromJson(json);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch user settings');
    } catch (e) {
      rethrow;
    }
  }

  Future<UserSettings> updateSettings(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(Api.userSettings(userId), data: data);
      final json = response.data['data'] as Map<String, dynamic>;
      return UserSettings.fromJson(json);
    } on DioException catch (e) {
      throwError(e, 'Failed to update user settings');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final response = await _dio.get(Api.userAchievements(userId));
      final data = response.data['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'] as List? ?? const [];

      return items
          .whereType<Map>()
          .map((json) => Achievement.fromJson(json.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch achievements');
    } catch (e) {
      rethrow;
    }
  }
}

final userService = UserService();
