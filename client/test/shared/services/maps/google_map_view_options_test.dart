import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/services/maps/google_map_view_options.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('GoogleMapViewOptions.resolve', () {
    test('uses cloud map id on web and skips manual style', () {
      final options = GoogleMapViewOptions.resolve(
        isWeb: true,
        platform: TargetPlatform.android,
        configuredWebMapId: 'web-map-id',
        configuredAndroidMapId: 'android-map-id',
        configuredIosMapId: 'ios-map-id',
        requestedStyle: '{"style":"custom"}',
        fallbackStyle: '{"style":"fallback"}',
      );

      expect(options.mapId, 'web-map-id');
      expect(options.style, isNull);
      expect(options.shouldReapplyStyleOnWeb, isFalse);
    });

    test('reapplies manual style on web when no cloud map id is set', () {
      final options = GoogleMapViewOptions.resolve(
        isWeb: true,
        platform: TargetPlatform.android,
        configuredWebMapId: '   ',
        configuredAndroidMapId: 'android-map-id',
        configuredIosMapId: 'ios-map-id',
        requestedStyle: null,
        fallbackStyle: '{"style":"fallback"}',
      );

      expect(options.mapId, isNull);
      expect(options.style, '{"style":"fallback"}');
      expect(options.shouldReapplyStyleOnWeb, isTrue);
    });

    test('uses android map id when configured', () {
      final options = GoogleMapViewOptions.resolve(
        isWeb: false,
        platform: TargetPlatform.android,
        configuredWebMapId: 'web-map-id',
        configuredAndroidMapId: 'android-map-id',
        configuredIosMapId: 'ios-map-id',
        requestedStyle: '{"style":"custom"}',
        fallbackStyle: '{"style":"fallback"}',
      );

      expect(options.mapId, 'android-map-id');
      expect(options.style, isNull);
      expect(options.shouldReapplyStyleOnWeb, isFalse);
    });

    test('uses ios map id when configured', () {
      final options = GoogleMapViewOptions.resolve(
        isWeb: false,
        platform: TargetPlatform.iOS,
        configuredWebMapId: 'web-map-id',
        configuredAndroidMapId: 'android-map-id',
        configuredIosMapId: 'ios-map-id',
        requestedStyle: '{"style":"custom"}',
        fallbackStyle: '{"style":"fallback"}',
      );

      expect(options.mapId, 'ios-map-id');
      expect(options.style, isNull);
      expect(options.shouldReapplyStyleOnWeb, isFalse);
    });

    test('keeps manual style on unsupported platforms without map id', () {
      final options = GoogleMapViewOptions.resolve(
        isWeb: false,
        platform: TargetPlatform.macOS,
        configuredWebMapId: 'web-map-id',
        configuredAndroidMapId: 'android-map-id',
        configuredIosMapId: 'ios-map-id',
        requestedStyle: '{"style":"custom"}',
        fallbackStyle: '{"style":"fallback"}',
      );

      expect(options.mapId, isNull);
      expect(options.style, '{"style":"custom"}');
      expect(options.shouldReapplyStyleOnWeb, isFalse);
    });
  });
}
