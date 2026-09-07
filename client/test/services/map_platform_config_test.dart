import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/services/maps/map_platform_config.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';

void main() {
  test('configureGoogleMapsPlatform enables Android view surface', () async {
    final mapsImplementation = GoogleMapsFlutterAndroid();

    expect(mapsImplementation.useAndroidViewSurface, isFalse);

    await configureGoogleMapsPlatform(
      mapsImplementation: mapsImplementation,
      initializeRenderer: false,
    );

    expect(mapsImplementation.useAndroidViewSurface, isTrue);
  });
}
