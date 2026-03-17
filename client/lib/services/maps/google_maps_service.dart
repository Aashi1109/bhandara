import 'package:dio/dio.dart';
import 'map_models.dart';
import 'map_provider_service.dart';
import 'map_provider_type.dart';

class GoogleMapsService implements MapProviderService {
  GoogleMapsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const String _nativeStyle = '''
[
  {
    "featureType": "administrative",
    "elementType": "all",
    "stylers": [{"saturation": "-100"}]
  },
  {
    "featureType": "administrative.province",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "landscape",
    "elementType": "all",
    "stylers": [{"saturation": -100}, {"lightness": 65}, {"visibility": "on"}]
  },
  {
    "featureType": "poi",
    "elementType": "all",
    "stylers": [
      {"saturation": -100},
      {"lightness": "50"},
      {"visibility": "simplified"}
    ]
  },
  {
    "featureType": "road",
    "elementType": "all",
    "stylers": [{"saturation": "-100"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "all",
    "stylers": [{"visibility": "simplified"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "all",
    "stylers": [{"lightness": "30"}]
  },
  {
    "featureType": "road.local",
    "elementType": "all",
    "stylers": [{"lightness": "40"}]
  },
  {
    "featureType": "transit",
    "elementType": "all",
    "stylers": [{"saturation": -100}, {"visibility": "simplified"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"hue": "#ffff00"}, {"lightness": -25}, {"saturation": -97}]
  },
  {
    "featureType": "water",
    "elementType": "labels",
    "stylers": [{"lightness": -25}, {"saturation": -100}]
  }
]
''';

  @override
  MapProviderType get type => MapProviderType.google;

  @override
  String get nativeMapStyle => _nativeStyle;

  @override
  Future<MapAddress?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.isEmpty) return null;

    final response = await _dio.get<dynamic>(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {'latlng': '$latitude,$longitude', 'key': _apiKey},
    );

    final results = (response.data as Map<String, dynamic>)['results'] as List?;
    if (results == null || results.isEmpty) return null;
    return _mapAddressFromGeocode(results.first as Map<String, dynamic>);
  }

  @override
  Future<List<MapAddress>> getCoordinatesFromAddress({
    required String address,
    int limit = 5,
  }) async {
    if (_apiKey.isEmpty || address.trim().isEmpty) {
      return const [];
    }

    final response = await _dio.get<dynamic>(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {'address': address, 'key': _apiKey},
    );

    final results = (response.data as Map<String, dynamic>)['results'] as List?;
    if (results == null || results.isEmpty) return const [];

    return results
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map(_mapAddressFromGeocode)
        .toList();
  }

  @override
  Future<List<MapSearchSuggestion>> searchPlaces({
    required String query,
    double? proximityLatitude,
    double? proximityLongitude,
    int limit = 5,
  }) async {
    if (_apiKey.isEmpty || query.trim().isEmpty) {
      return const [];
    }

    final params = <String, dynamic>{'input': query, 'key': _apiKey};
    if (proximityLatitude != null && proximityLongitude != null) {
      params['location'] = '$proximityLatitude,$proximityLongitude';
      params['radius'] = 50000;
    }

    final response = await _dio.get<dynamic>(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      queryParameters: params,
    );

    final predictions =
        (response.data as Map<String, dynamic>)['predictions'] as List?;
    if (predictions == null || predictions.isEmpty) return const [];

    return predictions
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map(
          (item) => MapSearchSuggestion(
            id: item['place_id']?.toString() ?? '',
            title:
                item['structured_formatting']?['main_text']?.toString() ??
                item['description']?.toString() ??
                '',
            subtitle: item['structured_formatting']?['secondary_text']
                ?.toString(),
            raw: item,
          ),
        )
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
    if (_apiKey.isEmpty) return fallbackUrl;

    final uri = Uri.https('maps.googleapis.com', '/maps/api/streetview', {
      'size': '${width}x$height',
      'location': '$latitude,$longitude',
      'fov': '$fov',
      'heading': '$heading',
      'pitch': '$pitch',
      'key': _apiKey,
    });
    return uri.toString();
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
    if (_apiKey.isEmpty) return fallbackUrl;

    final uri = Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
      'size': '${width}x$height',
      'center': '$latitude,$longitude',
      'zoom': '$zoom',
      'markers': '$latitude,$longitude',
      'key': _apiKey,
    });
    return uri.toString();
  }

  MapAddress _mapAddressFromGeocode(Map<String, dynamic> json) {
    final location =
        (json['geometry']?['location'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final lat = (location['lat'] as num?)?.toDouble() ?? 0;
    final lng = (location['lng'] as num?)?.toDouble() ?? 0;

    return MapAddress(
      formattedAddress: json['formatted_address']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      placeId: json['place_id']?.toString(),
      raw: json,
    );
  }
}
