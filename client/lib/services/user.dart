import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/user.dart';
import 'base.dart';

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

  Future<List<dynamic>> getUserInterests(String userId) async {
    try {
      final response = await _dio.get(Api.userInterests(userId));
      return response.data['data'] as List? ?? [];
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch user interests');
    } catch (e) {
      rethrow;
    }
  }
}

final userService = UserService();
