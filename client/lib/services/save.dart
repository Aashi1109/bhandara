import 'package:dio/dio.dart';

import '../constants/api.dart';
import '../models/save.dart';
import 'search.dart';
import 'api.dart';
import 'base.dart';

class SaveService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<SavedEntitySummary> getSaveState(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _dio.get(Api.saveEntity(entityType, entityId));
      return SavedEntitySummary.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch save state');
    } catch (e) {
      rethrow;
    }
  }

  Future<SavedEntitySummary> saveEntity(String entityType, String entityId) async {
    try {
      final response = await _dio.put(Api.saveEntity(entityType, entityId));
      return SavedEntitySummary.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to save entity');
    } catch (e) {
      rethrow;
    }
  }

  Future<SavedEntitySummary> unsaveEntity(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _dio.delete(Api.saveEntity(entityType, entityId));
      return SavedEntitySummary.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to unsave entity');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SearchResult>> getSavedResults() async {
    try {
      final response = await _dio.get(Api.saves);
      final data = response.data['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'] as List<dynamic>? ?? const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(_mapSavedItemToResult)
          .whereType<SearchResult>()
          .toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch saved items');
    } catch (e) {
      rethrow;
    }
  }

  SearchResult? _mapSavedItemToResult(Map<String, dynamic> item) {
    final entityType = item['entityType'] as String? ?? '';
    final entity = item['entity'];
    if (entity is! Map<String, dynamic>) {
      return null;
    }

    switch (entityType) {
      case 'event':
        return _mapSavedEvent(entity);
      case 'thread':
        return _mapSavedThread(entity);
      case 'message':
        return _mapSavedMessage(entity);
      default:
        return null;
    }
  }

  SearchResult _mapSavedEvent(Map<String, dynamic> entity) {
    final location = entity['location'] as Map<String, dynamic>? ?? const {};
    final media = entity['media'] as List<dynamic>? ?? const [];
    final mediaItems = media.whereType<Map<String, dynamic>>().toList();
    final firstMedia = mediaItems.isNotEmpty ? mediaItems.first : null;
    final timings = entity['timings'] as Map<String, dynamic>? ?? const {};

    return SearchResult(
      id: entity['id'] as String? ?? '',
      type: 'event',
      title: entity['name'] as String? ?? 'Untitled Event',
      description: location['address'] as String?,
      imageUrl: firstMedia?['url'] as String?,
      metadata: {
        'address': location['address'],
        'start': timings['start'],
        'end': timings['end'],
        'status': entity['status'],
      },
    );
  }

  SearchResult _mapSavedThread(Map<String, dynamic> entity) {
    final type = entity['type'] as String?;
    return SearchResult(
      id: entity['id'] as String? ?? '',
      type: 'thread',
      title: entity['title'] as String? ?? 'Untitled Thread',
      description: type != null && type.isNotEmpty ? type.toUpperCase() : null,
      metadata: {
        'eventId': entity['eventId'],
        'threadType': type,
        'createdAt': entity['createdAt'],
      },
    );
  }

  SearchResult _mapSavedMessage(Map<String, dynamic> entity) {
    final user = entity['user'] as Map<String, dynamic>?;
    final content = entity['content'];
    final contentMap = content is Map<String, dynamic> ? content : null;
    final media = contentMap?['media'] as List<dynamic>? ?? const [];
    final mediaItems = media.whereType<Map<String, dynamic>>().toList();
    final firstMedia = mediaItems.isNotEmpty ? mediaItems.first : null;
    final profilePic = user?['profilePic'] as Map<String, dynamic>?;
    final senderAvatar =
        user?['avatarUrl'] as String? ?? profilePic?['url'] as String?;

    return SearchResult(
      id: entity['id'] as String? ?? '',
      type: 'message',
      title: user?['name'] as String? ?? 'Message',
      description:
          (contentMap?['text'] as String?) ??
          (content is String ? content : null) ??
          'Open message',
      imageUrl: firstMedia?['url'] as String? ?? senderAvatar,
      metadata: {
        'threadId': entity['threadId'],
        'message': entity,
        'createdAt': entity['createdAt'],
      },
    );
  }
}

final saveService = SaveService();
