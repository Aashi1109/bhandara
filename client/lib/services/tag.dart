import 'package:dio/dio.dart';
import '../constants/api.dart';
import 'api.dart';
import '../models/event.dart';
import 'base.dart';

class TagService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<List<Tag>> getTags({bool rootOnly = false, String? parentId}) async {
    try {
      final response = await _dio.get(
        Api.tags,
        queryParameters: {'rootOnly': rootOnly, 'parentId': parentId},
      );
      final dynamic data = response.data['data'];
      List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = [];
      }
      return items
          .map((json) => Tag.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch tags');
    } catch (e) {
      rethrow;
    }
  }
}

final tagService = TagService();
