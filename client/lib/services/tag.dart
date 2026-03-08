import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/api_response.dart';
import '../models/event.dart';
import 'base.dart';

class TagService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<ApiResponse<List<Tag>>> getTags({bool rootOnly = false}) async {
    try {
      final response = await _dio.get(
        Api.tags,
        queryParameters: {'rootOnly': rootOnly},
      );

      final data = response.data['data'];
      if (data is List) {
        return ApiResponse(
          data: data
              .map((json) => Tag.fromJson(json as Map<String, dynamic>))
              .toList(),
        );
      }

      return ApiResponse.fromJson(
        response.data,
        (json) => (json as List)
            .map((t) => Tag.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return handleError(e, 'Failed to fetch tags');
    } catch (e) {
      return ApiResponse(error: 'An unexpected error occurred');
    }
  }
}

final tagService = TagService();
