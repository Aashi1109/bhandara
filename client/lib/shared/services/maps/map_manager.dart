import './map_models.dart';
import './map_provider_service.dart';
import './map_provider_type.dart';
import './google_maps_service.dart';
import './mapbox_maps_service.dart';

class MapManager {
  MapManager({required MapProviderType type}) : _service = _buildService(type);

  final MapProviderService _service;

  static MapProviderService _buildService(MapProviderType type) {
    switch (type) {
      case MapProviderType.mapbox:
        return MapboxMapsService();
      case MapProviderType.google:
        return GoogleMapsService();
    }
  }

  String get nativeMapStyle => _service.nativeMapStyle;

  Future<MapAddress?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return _service.getAddressFromCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<MapAddress>> getCoordinatesFromAddress({
    required String address,
    int limit = 5,
  }) {
    return _service.getCoordinatesFromAddress(address: address, limit: limit);
  }

  Future<List<MapSearchSuggestion>> searchPlaces({
    required String query,
    double? proximityLatitude,
    double? proximityLongitude,
    int limit = 5,
  }) {
    return _service.searchPlaces(
      query: query,
      proximityLatitude: proximityLatitude,
      proximityLongitude: proximityLongitude,
      limit: limit,
    );
  }

  String getStreetViewImageUrl({
    required double latitude,
    required double longitude,
    int width = 1000,
    int height = 1000,
    int heading = 0,
    int pitch = 0,
    int fov = 80,
    String fallbackUrl = 'https://picsum.photos/seed/nyc-map/1000/1000',
  }) {
    return _service.getStreetViewImageUrl(
      latitude: latitude,
      longitude: longitude,
      width: width,
      height: height,
      heading: heading,
      pitch: pitch,
      fov: fov,
      fallbackUrl: fallbackUrl,
    );
  }

  String getStaticMapImageUrl({
    required double latitude,
    required double longitude,
    int width = 1000,
    int height = 1000,
    double zoom = 14,
    bool showMarker = true,
    String? customMarkerUrl = defaultStaticMapMarkerUrl,
    String fallbackUrl = 'https://picsum.photos/seed/nyc-map/1000/1000',
  }) {
    return _service.getStaticMapImageUrl(
      latitude: latitude,
      longitude: longitude,
      width: width,
      height: height,
      zoom: zoom,
      showMarker: showMarker,
      customMarkerUrl: customMarkerUrl,
      fallbackUrl: fallbackUrl,
    );
  }
}
