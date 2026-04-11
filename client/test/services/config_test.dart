import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/config.dart';

void main() {
  group('AppConfig.resolveApiHost', () {
    test('maps localhost to Android emulator loopback outside web', () {
      expect(
        AppConfig.resolveApiHost(
          configuredHost: 'localhost',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        '10.0.2.2',
      );
    });

    test('keeps localhost unchanged on web', () {
      expect(
        AppConfig.resolveApiHost(
          configuredHost: 'localhost',
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'localhost',
      );
    });
  });

  group('AppConfig.resolveClientPlatform', () {
    test('returns web for web builds', () {
      expect(
        AppConfig.resolveClientPlatform(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'web',
      );
    });

    test('returns iOS for native iOS builds', () {
      expect(
        AppConfig.resolveClientPlatform(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        'ios',
      );
    });
  });
}
