import 'package:dio/dio.dart';
import '../../../shared/constants/api.dart';
import '../../../shared/services/api.dart';
import '../../../shared/models/api_response.dart';
import '../../../shared/services/base.dart';

class SearchResult {
  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    this.metadata,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String type;
  final String title;
  final String? description;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
}

class SearchService extends BaseService {
  final Dio _dio = apiService.dio;

  Future<PaginatedResponse<SearchResult>> search(
    String query, {
    String? next,
    int limit = 20,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'query': query, 'limit': limit};
      if (next != null) {
        queryParameters['next'] = next;
      }
      if (filters != null) {
        queryParameters.addAll(filters);
      }

      final response = await _dio.get(
        Api.search,
        queryParameters: queryParameters,
      );

      return PaginatedResponse<SearchResult>.fromJson(
        response.data['data'] as Map<String, dynamic>,
        (json) => SearchResult.fromJson(json! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwError(e, 'Search failed');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getSuggestions(String query, {int limit = 5}) async {
    try {
      final response = await _dio.get(
        Api.searchSuggestions,
        queryParameters: {'query': query, 'limit': limit},
      );
      final data = response.data['data'] as List? ?? [];
      return data.map((e) => e as String).toList();
    } on DioException catch (e) {
      throwError(e, 'Failed to fetch suggestions');
    } catch (e) {
      rethrow;
    }
  }
}

final searchService = SearchService();
