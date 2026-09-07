import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../shared/constants/api.dart';
import '../../../shared/services/api.dart';
import '../../../shared/models/api_response.dart';
import '../models/event.dart';
import '../../explore/models/event_marker.dart';
import '../../../shared/services/base.dart';

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

  Future<Event> verifyAttendance(
    String eventId,
    Map<String, double> coordinates,
  ) async {
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

  /// Fetches individual event markers inside a padded circle.
  ///
  /// [cancelToken] lets the caller abort a request that a newer viewport has
  /// already superseded instead of paying for a response it will discard.
  Future<EventMarkerPage> getFlatEventMarkers({
    String? status,
    String? type,
    String? datePreset,
    required double latitude,
    required double longitude,
    required double radiusKm,
    Set<String>? tagIds,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        Api.eventMarkers,
        queryParameters: {
          'flat': true,
          'status': status,
          'type': type,
          'datePreset': datePreset,
          'latitude': latitude,
          'longitude': longitude,
          'radiusKm': radiusKm,
          'tagIds': tagIds?.isEmpty == true ? null : tagIds?.join(','),
        },
        cancelToken: cancelToken,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return EventMarkerPage(
        markers: items
            .map((e) => EventMarker.fromJson(e as Map<String, dynamic>))
            .toList(),
        center: LatLng(
          (data['latitude'] as num?)?.toDouble() ?? latitude,
          (data['longitude'] as num?)?.toDouble() ?? longitude,
        ),
        radiusKm: (data['radiusKm'] as num?)?.toDouble() ?? radiusKm,
        truncated: data['truncated'] == true,
      );
    } on DioException {
      // Marker fetches are background work: no global snackbar. Cancellations
      // are routine (a newer viewport superseded this one) and the caller
      // surfaces real failures with an inline retry.
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
