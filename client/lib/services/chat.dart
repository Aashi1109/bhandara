import 'package:dio/dio.dart';
import '../constants/api.dart';
import '../constants/socket_events.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/chat.dart';
import 'base.dart';
import 'socket.dart';

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

  Future<PaginatedResponse<Thread>> getEventThreads(
    String eventId, {
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

  Future<Thread> createThread(
    String eventId, {
    String visibility = 'public',
  }) async {
    try {
      final response = await _dio.post(
        Api.eventThreads(eventId),
        data: {'eventId': eventId, 'visibility': visibility},
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

  Future<Thread> getThread(String threadId) async {
    try {
      final response = await _dio.get(Api.threadById(threadId));
      return Thread.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch thread');
    } catch (e) {
      rethrow;
    }
  }

  Future<PaginatedResponse<Message>> getMessages(
    String threadId, {
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

  Future<PaginatedResponse<Message>> getChildMessages(
    String threadId,
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

  Future<Message> sendMessage(
    String threadId,
    String content, {
    List<String>? mediaIds,
    String? parentId,
  }) async {
    try {
      final trimmedContent = content.trim();
      final normalizedMediaIds = (mediaIds ?? const <String>[])
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      final hasMedia = normalizedMediaIds.isNotEmpty;
      final messageContent = hasMedia
          ? _compactMap({
              'text': trimmedContent.isEmpty ? null : trimmedContent,
              'media': normalizedMediaIds,
            })
          : trimmedContent;

      final ack = await socketService.emit(
        SocketEvents.messageCreate,
        _compactMap({
          'threadId': threadId,
          'content': messageContent,
          'parentId': parentId,
        }),
      );

      final normalizedAck = ack is List && ack.isNotEmpty ? ack.first : ack;
      if (normalizedAck is Map && normalizedAck['error'] != null) {
        throw Exception(
          normalizedAck['error']?.toString() ?? 'Failed to send message',
        );
      }

      final payload =
          normalizedAck is Map<String, dynamic> &&
              normalizedAck['data'] is Map<String, dynamic>
          ? normalizedAck['data'] as Map<String, dynamic>
          : normalizedAck is Map<String, dynamic>
          ? normalizedAck
          : null;

      if (payload == null) {
        throw Exception('Invalid message acknowledgement received');
      }

      return Message.fromJson(payload);
    } on DioException catch (e) {
      throwError(e, 'Failed to send message');
    } catch (e) {
      rethrow;
    }
  }

  Future<Message> updateMessage(
    String threadId,
    String messageId,
    String content,
  ) async {
    try {
      final response = await _dio.put(
        Api.threadMessage(threadId, messageId),
        data: {
          'content': {'text': content},
        },
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
