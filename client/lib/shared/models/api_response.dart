class ApiResponse<T> {
  ApiResponse({this.data, this.error});

  factory ApiResponse.fromJson(Map<String, dynamic> json,
      T Function(Object? json) fromJsonT,) {
    return ApiResponse<T>(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      error: json['error'] is String
          ? json['error'] as String
          : json['error'] is Map
          ? (json['error'] as Map)['message'] as String?
          : null,
    );
  }

  final T? data;
  final String? error;
}

class PaginatedResponse<T> {
  PaginatedResponse({required this.items, required this.pagination});

  factory PaginatedResponse.fromJson(Map<String, dynamic> json,
      T Function(Object? json) fromJsonT,) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final paginationJson = json['pagination'] as Map<String, dynamic>?;

    return PaginatedResponse<T>(
      items: itemsJson.map(fromJsonT).toList(),
      pagination: paginationJson != null
          ? Pagination.fromJson(paginationJson)
          : Pagination(
        total: itemsJson.length,
        limit: itemsJson.length,
        hasNext: false,
      ),
    );
  }

  final List<T> items;
  final Pagination pagination;
}

class Pagination {
  Pagination({
    required this.total,
    required this.limit,
    required this.hasNext,
    this.next,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: (json['total'] ?? 0) as int,
      limit: (json['limit'] ?? 10) as int,
      hasNext: (json['hasNext'] ?? false) as bool,
      next: json['next'] as String?,
    );
  }

  final int total;
  final int limit;
  final bool hasNext;
  final String? next;
}
