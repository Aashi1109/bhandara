import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/chat.dart';
import 'base.dart';

class ChatService extends BaseService {
  final Dio _dio = apiService.dio;

  Map<String, dynamic> _compactMap(Map<String, dynamic> input) {
    final map = <String, dynamic>{};
    input.forEach((key, value) {
      if (value != null) {
        map[key] = value;
      }
    });
    return map;
  }

  Future<PaginatedResponse<Thread>> getEventThreads(String eventId, {
    String? next,
    int? limit,
  }) async {
    try {
      final response = await _dio.get(
        Api.eventThreads(eventId),
        queryParameters: _compactMap({'next': next, 'limit': limit}),
      );
      return PaginatedResponse<Thread>.fromJson(
        response.data['data'] as Map<String, dynamic>,
            (e) => Thread.fromJson(e! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch event threads');
    } catch (e) {
      rethrow;
    }
  }

  Future<Thread> createThread(String eventId, {
    String? title,
    String type = 'general',
  }) async {
    try {
      final response = await _dio.post(
        Api.eventThreads(eventId),
        data: _compactMap({'title': title, 'type': type}),
      );
      return Thread.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to create thread');
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginatedResponse<Thread>> getThreads({String? eventId}) async {
    try {
      final response = await _dio.get(
        Api.threads,
        queryParameters: _compactMap({'eventId': eventId}),
      );
      return PaginatedResponse<Thread>.fromJson(
        response.data['data'] as Map<String, dynamic>,
            (e) => Thread.fromJson(e! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch threads');
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginatedResponse<Message>> getMessages(String threadId, {
    String? next,
    int? limit,
  }) async {
    try {
      final response = await _dio.get(
        Api.threadMessages(threadId),
        queryParameters: _compactMap({'next': next, 'limit': limit}),
      );
      return PaginatedResponse<Message>.fromJson(
        response.data['data'] as Map<String, dynamic>,
            (e) => Message.fromJson(e! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch messages');
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginatedResponse<Message>> getChildMessages(String threadId,
      String parentId, {
        String? next,
        int? limit,
      }) async {
    try {
      final response = await _dio.get(
        Api.threadChildMessages(threadId, parentId),
        queryParameters: _compactMap({'next': next, 'limit': limit}),
      );
      return PaginatedResponse<Message>.fromJson(
        response.data['data'] as Map<String, dynamic>,
            (e) => Message.fromJson(e! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch replies');
    } catch (e) {
      rethrow;
    }
  }

  Future<Message> getMessage(String threadId, String messageId) async {
    try {
      final response = await _dio.get(Api.threadMessage(threadId, messageId));
      return Message.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch message');
    } catch (e) {
      rethrow;
    }
  }

  Future<Message> sendMessage(String threadId,
      String content, {
        String? type,
        List<String>? mediaIds,
        String? parentId,
      }) async {
    try {
      final trimmedContent = content.trim();
      final hasMedia = mediaIds != null && mediaIds.isNotEmpty;
      final messageContent = hasMedia
          ? _compactMap({
              'text': trimmedContent.isEmpty ? null : trimmedContent,
              'media': mediaIds,
            })
          : {'text': trimmedContent};

      final response = await _dio.post(
        Api.threadMessages(threadId),
        data: _compactMap({
          'content': messageContent,
          'type': type,
          'parentId': parentId,
        }),
      );
      return Message.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to send message');
    } catch (e) {
      rethrow;
    }
  }

  Future<Message> updateMessage(String threadId,
      String messageId,
      String content,) async {
    try {
      final response = await _dio.put(
        Api.threadMessage(threadId, messageId),
        data: {'content': {'text': content}},
      );
      return Message.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to update message');
    } catch (e) {
      rethrow;
    }
  }

  Future<Message> deleteMessage(String threadId, String messageId) async {
    try {
      final response = await _dio.delete(
        Api.threadMessage(threadId, messageId),
      );
      return Message.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to delete message');
    } catch (e) {
      rethrow;
    }
  }

  Future<Thread> lockThread(String threadId) async {
    try {
      final response = await _dio.post(Api.lockThread(threadId));
      return Thread.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to lock thread');
    } catch (e) {
      rethrow;
    }
  }

  Future<Thread> unlockThread(String threadId) async {
    try {
      final response = await _dio.post(Api.unlockThread(threadId));
      return Thread.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to unlock thread');
    } catch (e) {
      rethrow;
    }
  }
}

final chatService = ChatService();
