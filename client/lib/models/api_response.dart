class ApiResponse<T> {
  ApiResponse({this.data, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
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

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      items: (json['items'] as List<dynamic>).map(fromJsonT).toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
  final List<T> items;
  final Pagination pagination;
}

class Pagination {
  Pagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}
