import 'package:dio/dio.dart';

import '../constants/api.dart';
import '../models/engagement.dart';
import 'api.dart';
import 'base.dart';

class EngagementService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<EngagementSummary> getEntityEngagement(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _dio.get(Api.engagement(entityType, entityId));
      return EngagementSummary.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch engagement');
    } catch (e) {
      rethrow;
    }
  }

  Future<EngagementSummary> rateEntity(
    String entityType,
    String entityId,
    int value,
    {String? review}
  ) async {
    try {
      final response = await _dio.put(
        Api.engagementRating(entityType, entityId),
        data: {
          'value': value,
          'review': review,
        },
      );
      return EngagementSummary.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to submit rating');
    } catch (e) {
      rethrow;
    }
  }

  Future<EngagementSummary> deleteEntityRating(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _dio.delete(
        Api.engagementRating(entityType, entityId),
      );
      return EngagementSummary.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to remove rating');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EventReview>> getEntityRatings(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _dio.get(Api.engagementRatings(entityType, entityId));
      return (response.data['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EventReview.fromJson)
          .toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch ratings');
    } catch (e) {
      rethrow;
    }
  }
}

final engagementService = EngagementService();
