import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

void configureDioForPlatform(Dio dio) {
  (dio.httpClientAdapter as BrowserHttpClientAdapter).withCredentials = true;
}
