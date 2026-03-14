import 'package:dio/dio.dart';
import 'map_models.dart';
import 'map_provider_service.dart';
import 'map_provider_type.dart';

class MapboxMapsService implements MapProviderService {
  MapboxMapsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const String _styleId = String.fromEnvironment(
    'MAPBOX_STYLE_ID',
    defaultValue: 'mapbox/streets-v12',
  );

  @override
  MapProviderType get type => MapProviderType.mapbox;

  @override
  String get nativeMapStyle => '';

  @override
  Future<MapAddress?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    if (_accessToken.isEmpty) return null;

    final encoded = Uri.encodeComponent('$longitude,$latitude');
    final response = await _dio.get<dynamic>(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json',
      queryParameters: {'access_token': _accessToken, 'limit': 1},
    );

    final features =
        (response.data as Map<String, dynamic>)['features'] as List?;
    if (features == null || features.isEmpty) return null;
    return _mapAddressFromFeature(features.first as Map<String, dynamic>);
  }

  @override
  Future<List<MapAddress>> getCoordinatesFromAddress({
    required String address,
    int limit = 5,
  }) async {
    if (_accessToken.isEmpty || address.trim().isEmpty) return const [];

    final encoded = Uri.encodeComponent(address);
    final response = await _dio.get<dynamic>(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json',
      queryParameters: {'access_token': _accessToken, 'limit': limit},
    );

    final features =
        (response.data as Map<String, dynamic>)['features'] as List?;
    if (features == null || features.isEmpty) return const [];

    return features
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map(_mapAddressFromFeature)
        .toList();
  }

  @override
  Future<List<MapSearchSuggestion>> searchPlaces({
    required String query,
    double? proximityLatitude,
    double? proximityLongitude,
    int limit = 5,
  }) async {
    if (_accessToken.isEmpty || query.trim().isEmpty) return const [];

    final encoded = Uri.encodeComponent(query);
    final params = <String, dynamic>{
      'access_token': _accessToken,
      'autocomplete': true,
      'limit': limit,
    };
    if (proximityLatitude != null && proximityLongitude != null) {
      params['proximity'] = '$proximityLongitude,$proximityLatitude';
    }

    final response = await _dio.get<dynamic>(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json',
      queryParameters: params,
    );

    final features =
        (response.data as Map<String, dynamic>)['features'] as List?;
    if (features == null || features.isEmpty) return const [];

    return features
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map((feature) {
          final center = feature['center'] as List?;
          final lng = (center != null && center.isNotEmpty)
              ? (center.first as num?)?.toDouble()
              : null;
          final lat = (center != null && center.length > 1)
              ? (center[1] as num?)?.toDouble()
              : null;

          final context = feature['context'] as List?;
          final subtitle = context
              ?.whereType<Map<String, dynamic>>()
              .map((e) => e['text']?.toString())
              .whereType<String>()
              .join(', ');

          return MapSearchSuggestion(
            id: feature['id']?.toString() ?? '',
            title: feature['text']?.toString() ?? '',
            subtitle: subtitle?.isEmpty ?? true ? null : subtitle,
            latitude: lat,
            longitude: lng,
            raw: feature,
          );
        })
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();
  }

  @override
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
    return getStaticMapImageUrl(
      latitude: latitude,
      longitude: longitude,
      width: width,
      height: height,
      zoom: 14,
      fallbackUrl: fallbackUrl,
    );
  }

  @override
  String getStaticMapImageUrl({
    required double latitude,
    required double longitude,
    int width = 1000,
    int height = 1000,
    double zoom = 14,
    String fallbackUrl = 'https://picsum.photos/seed/nyc-map/1000/1000',
  }) {
    if (_accessToken.isEmpty) return fallbackUrl;

    final path =
        '/styles/v1/$_styleId/static/pin-s+000($longitude,$latitude)/$longitude,$latitude,$zoom/{$width}x{$height}';
    final resolvedPath = path
        .replaceAll('{$width}', '$width')
        .replaceAll('{$height}', '$height');
    final uri = Uri.https('api.mapbox.com', resolvedPath, {
      'access_token': _accessToken,
    });
    return uri.toString();
  }

  MapAddress _mapAddressFromFeature(Map<String, dynamic> feature) {
    final center = feature['center'] as List?;
    final double lng = (center != null && center.isNotEmpty)
        ? (center.first as num?)?.toDouble() ?? 0
        : 0.0;
    final double lat = (center != null && center.length > 1)
        ? (center[1] as num?)?.toDouble() ?? 0
        : 0.0;

    return MapAddress(
      formattedAddress: feature['place_name']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      placeId: feature['id']?.toString(),
      raw: feature,
    );
  }
}
