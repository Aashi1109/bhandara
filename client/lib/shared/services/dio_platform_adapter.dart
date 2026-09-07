import 'dio_platform_adapter_stub.dart'
    if (dart.library.html) 'dio_platform_adapter_web.dart'
    as impl;

import 'package:dio/dio.dart';

void configureDioForPlatform(Dio dio) {
  impl.configureDioForPlatform(dio);
}
