import 'package:dio/dio.dart';
import '../models/api_response.dart';

abstract class BaseService {
  ApiResponse<T> handleError<T>(DioException e, String defaultMessage) {
    String message = defaultMessage;
    final response = e.response;

    if (response != null && response.data is Map) {
      final errorData = response.data['error'];
      if (errorData is String) {
        message = errorData;
      } else if (errorData is Map && errorData['message'] is String) {
        message = errorData['message'] as String;
      }
    }

    return ApiResponse(error: message);
  }
}
