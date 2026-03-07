import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/event.dart';

class EventService {
  final Dio _dio = apiService.dio;

  Future<ApiResponse<PaginatedResponse<Event>>> getEvents({
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        Api.events,
        queryParameters: {'status': ?status},
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => PaginatedResponse<Event>.fromJson(
          json as Map<String, dynamic>,
          (e) => Event.fromJson(e as Map<String, dynamic>),
        ),
      );
    } on DioException catch (e) {
      return ApiResponse(
        error: e.response?.data['error'] ?? 'Failed to fetch events',
      );
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<ApiResponse<Event>> createEvent(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(Api.events, data: data);
      return ApiResponse.fromJson(
        response.data,
        (json) => Event.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return ApiResponse(
        error: e.response?.data['error'] ?? 'Failed to create event',
      );
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }
}

final eventService = EventService();
