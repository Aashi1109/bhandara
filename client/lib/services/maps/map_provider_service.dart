import 'map_models.dart';
import 'map_provider_type.dart';

abstract interface class MapProviderService {
  MapProviderType get type;

  String get nativeMapStyle;

  Future<MapAddress?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  });

  Future<List<MapAddress>> getCoordinatesFromAddress({
    required String address,
    int limit = 5,
  });

  Future<List<MapSearchSuggestion>> searchPlaces({
    required String query,
    double? proximityLatitude,
    double? proximityLongitude,
    int limit = 5,
  });

  String getStreetViewImageUrl({
    required double latitude,
    required double longitude,
    int width = 1000,
    int height = 1000,
    int heading = 0,
    int pitch = 0,
    int fov = 80,
    String fallbackUrl = 'https://picsum.photos/seed/nyc-map/1000/1000',
  });

  String getStaticMapImageUrl({
    required double latitude,
    required double longitude,
    int width = 1000,
    int height = 1000,
    double zoom = 14,
    String fallbackUrl = 'https://picsum.photos/seed/nyc-map/1000/1000',
  });
}
