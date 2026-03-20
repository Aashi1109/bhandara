import 'package:dio/dio.dart';

import '../constants/api.dart';
import '../models/api_response.dart';
import '../models/update.dart';
import 'api.dart';
import 'base.dart';

class ActivityService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<PaginatedResponse<AppUpdate>> getUserActivity(
    String userId, {
    bool includePrivate = false,
    List<String>? types,
    String? next,
    int limit = 20,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'includePrivate': includePrivate,
        'limit': limit,
      };
      if (next != null) {
        queryParameters['next'] = next;
      }
      if (types != null && types.isNotEmpty) {
        queryParameters['type'] = types.join(',');
      }

      final response = await _dio.get(
        Api.userActivity(userId),
        queryParameters: queryParameters,
      );

      return PaginatedResponse<AppUpdate>.fromJson(
        response.data['data'] as Map<String, dynamic>,
        (json) => AppUpdate.fromJson(json! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch activity');
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginatedResponse<AppUpdate>> getMyUpdates({
    bool unreadOnly = false,
    List<String>? types,
    String? next,
    int limit = 20,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'unreadOnly': unreadOnly,
        'limit': limit,
      };
      if (next != null) {
        queryParameters['next'] = next;
      }
      if (types != null && types.isNotEmpty) {
        queryParameters['type'] = types.join(',');
      }

      final response = await _dio.get(
        Api.myUpdates,
        queryParameters: queryParameters,
      );

      return PaginatedResponse<AppUpdate>.fromJson(
        response.data['data'] as Map<String, dynamic>,
        (json) => AppUpdate.fromJson(json! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch updates');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch(Api.markAllMyUpdatesRead);
    } on DioException catch (e) {
      throwError(e, 'Failed to mark updates as read');
    } catch (e) {
      rethrow;
    }
  }

  Future<AppUpdate> markRead(String activityId) async {
    try {
      final response = await _dio.patch(Api.markMyUpdateRead(activityId));
      return AppUpdate.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to mark update as read');
    } catch (e) {
      rethrow;
    }
  }
}

final activityService = ActivityService();
