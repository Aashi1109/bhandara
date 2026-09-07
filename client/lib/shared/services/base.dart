import 'package:dio/dio.dart';
import '../widgets/snackbar.dart';

abstract class BaseService {
  Never throwError(DioException e, String defaultMessage) {
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

    AppSnackBar.showGlobal(message: message, type: SnackBarType.error);
    throw Exception(message);
  }
}
