import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/event.dart';
import 'base.dart';

class EventService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<PaginatedResponse<Event>> getEvents({
    String? status,
    String? createdBy,
    int? limit,
    String? next,
  }) async {
    try {
      final response = await _dio.get(
        Api.events,
        queryParameters: {
          'status': status,
          'createdBy': createdBy,
          'limit': limit,
          'next': next,
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
