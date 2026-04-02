import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/event.dart';
import '../screens/explore/models/event_cluster.dart';
import '../screens/explore/models/event_marker.dart';
import 'base.dart';

class EventService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<PaginatedResponse<Event>> getEvents({
    String? status,
    String? createdBy,
    String? type,
    String? datePreset,
    double? latitude,
    double? longitude,
    double? radiusKm,
    Set<String>? tagIds,
    int? limit,
    String? next,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final response = await _dio.get(
        Api.events,
        queryParameters: {
          'status': status,
          'createdBy': createdBy,
          'type': type,
          'datePreset': datePreset,
          'latitude': latitude,
          'longitude': longitude,
          'radiusKm': radiusKm,
          'tagIds': tagIds?.isEmpty == true ? null : tagIds?.join(','),
          'limit': limit,
          'next': next,
          'sortBy': sortBy,
          'sortOrder': sortOrder,
        },
      );
      return PaginatedResponse<Event>.fromJson(
        response.data['data'] as Map<String, dynamic>,
            (e) => Event.fromJson(e! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch events');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> getEvent(String eventId) async {
    try {
      final response = await _dio.get(Api.eventById(eventId));
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch event');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> getEventPreview(String eventId) async {
    try {
      final response = await _dio.get(
        Api.eventById(eventId),
        queryParameters: const {'view': 'preview'},
      );
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch event preview');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> createEvent(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(Api.events, data: data);
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to create event');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> updateEvent(String eventId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(Api.eventById(eventId), data: data);
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to update event');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> joinEvent(String eventId) async {
    try {
      final response = await _dio.get(Api.eventAction(eventId, 'join'));
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to join event');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> leaveEvent(String eventId) async {
    try {
      final response = await _dio.get(Api.eventAction(eventId, 'leave'));
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to leave event');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> verifyAttendance(String eventId,
      Map<String, double> coordinates,) async {
    try {
      final response = await _dio.post(
        Api.verifyEvent(eventId),
        data: {'currentCoordinates': coordinates},
      );
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to verify attendance');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EventCluster>> getEventClusters({
    String? status,
    String? type,
    String? datePreset,
    double? latitude,
    double? longitude,
    double? radiusKm,
    Set<String>? tagIds,
    required int zoom,
  }) async {
    try {
      final response = await _dio.get(
        Api.eventMarkers,
        queryParameters: {
          'status': status,
          'type': type,
          'datePreset': datePreset,
          'latitude': latitude,
          'longitude': longitude,
          'radiusKm': radiusKm,
          'tagIds': tagIds?.isEmpty == true ? null : tagIds?.join(','),
          'zoom': zoom,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((e) => EventCluster.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch event clusters');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, List<EventMarker>>> getEventMarkersByTiles({
    required Set<String> tiles,
    String? status,
    String? type,
    String? datePreset,
    Set<String>? tagIds,
    required int zoom,
  }) async {
    try {
      final response = await _dio.get(
        Api.eventMarkers,
        queryParameters: {
          'tiles': tiles.join(','),
          'status': status,
          'type': type,
          'datePreset': datePreset,
          'tagIds': tagIds?.isEmpty == true ? null : tagIds?.join(','),
          'zoom': zoom,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final items = data['items'] as Map<String, dynamic>;
      return items.map((key, value) {
        final markers = (value as List<dynamic>)
            .map((e) => EventMarker.fromJson(e as Map<String, dynamic>))
            .toList();
        return MapEntry(key, markers);
      });
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch event markers');
    } catch (e) {
      rethrow;
    }
  }

  Future<Event> deleteEventMedia(String eventId, String mediaId) async {
    try {
      final response = await _dio.delete(Api.eventMedia(eventId, mediaId));
      return Event.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwError(e, 'Failed to remove event media');
    } catch (e) {
      rethrow;
    }
  }
}

final eventService = EventService();
