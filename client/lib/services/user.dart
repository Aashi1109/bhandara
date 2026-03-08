import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/user.dart';
import 'base.dart';

class UserService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<ApiResponse<User>> getCurrentUser() async {
    try {
      final response = await _dio.get(Api.session);
      return ApiResponse.fromJson(
        response.data,
        (json) => User.fromJson(
          (json! as Map<String, dynamic>)['user'] as Map<String, dynamic>,
        ),
      );
    } on DioException catch (e) {
      return handleError(e, 'Failed to fetch user');
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<ApiResponse<User>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(Api.updateUser(id), data: data);
      return ApiResponse.fromJson(
        response.data,
        (json) => User.fromJson(json! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return handleError(e, 'Failed to update profile');
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<ApiResponse<PaginatedResponse<User>>> getByQuery({
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
      return ApiResponse.fromJson(
        response.data,
        (json) => PaginatedResponse<User>.fromJson(
          json! as Map<String, dynamic>,
          (json) => User.fromJson(json! as Map<String, dynamic>),
        ),
      );
    } on DioException catch (e) {
      return handleError(e, 'Failed to fetch user');
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }
}

final userService = UserService();
