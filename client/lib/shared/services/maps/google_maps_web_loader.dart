import 'google_maps_web_loader_stub.dart'
    if (dart.library.html) 'google_maps_web_loader_web.dart'
    as impl;

Future<void> ensureGoogleMapsWebSdkLoaded(String apiKey) {
  return impl.ensureGoogleMapsWebSdkLoaded(apiKey);
}
