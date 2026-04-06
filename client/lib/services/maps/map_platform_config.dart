import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

Future<void> configureGoogleMapsPlatform({
  GoogleMapsFlutterPlatform? mapsImplementation,
  bool initializeRenderer = true,
  bool warmupSdk = false,
}) async {
  final implementation =
      mapsImplementation ?? GoogleMapsFlutterPlatform.instance;

  if (implementation is GoogleMapsFlutterAndroid) {
    implementation.useAndroidViewSurface = true;
    if (!initializeRenderer) {
      return;
    }

    try {
      await implementation.initializeWithRenderer(AndroidMapRenderer.latest);
    } catch (_) {
      // Renderer selection is one-shot per process. If it was already
      // initialized elsewhere, keep the chosen renderer and continue.
    }

    if (!warmupSdk) {
      return;
    }

    try {
      await implementation.warmup();
    } catch (_) {
      // Warmup is an optimization only; ignore failures and let map creation
      // continue normally.
    }
  }
}
