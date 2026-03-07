import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/chat.dart';

class ChatService {
  final Dio _dio = apiService.dio;

  Future<ApiResponse<PaginatedResponse<Thread>>> getThreads({
    String? eventId,
  }) async {
    try {
      final response = await _dio.get(
        // we can just use the path without eventId if the backend allows top-level threads query, let's keep the existing '/threads' path, wait... there is no '/threads' constant, let's just make one or retain it. Actually, I should add `threads` to the constants. I'll add threads later or adjust now.
        Api.threads, // Will fix this in another replace
        queryParameters: {'eventId': ?eventId},
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => PaginatedResponse<Thread>.fromJson(
          json as Map<String, dynamic>,
          (e) => Thread.fromJson(e as Map<String, dynamic>),
        ),
      );
    } on DioException catch (e) {
      return ApiResponse(
        error: e.response?.data['error'] ?? 'Failed to fetch threads',
      );
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<ApiResponse<PaginatedResponse<Message>>> getMessages(
    String threadId, {
    int? page,
    int? limit,
  }) async {
    try {
      final response = await _dio.get(
        Api.threadMessages(threadId),
        queryParameters: {'page': ?page, 'limit': ?limit},
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => PaginatedResponse<Message>.fromJson(
          json as Map<String, dynamic>,
          (e) => Message.fromJson(e as Map<String, dynamic>),
        ),
      );
    } on DioException catch (e) {
      return ApiResponse(
        error: e.response?.data['error'] ?? 'Failed to fetch messages',
      );
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }

  Future<ApiResponse<Message>> sendMessage(
    String threadId,
    String content, {
    String? type,
  }) async {
    try {
      final response = await _dio.post(
        Api.threadMessages(threadId),
        data: {
          'content': {'text': content},
          'type': ?type,
        },
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => Message.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return ApiResponse(
        error: e.response?.data['error'] ?? 'Failed to send message',
      );
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }
}

final chatService = ChatService();
