import 'dart:math' as math;

import 'package:dio/dio.dart';
import '../../../config.dart';
import './map_models.dart';
import './map_provider_service.dart';
import './map_provider_type.dart';
import './google_maps_styles.dart';

class GoogleMapsService implements MapProviderService {
  GoogleMapsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _apiKey = AppConfig.googleMapsApiKey;

  static const List<String> _staticMapStyles = [
    'feature:all|element:labels.icon|visibility:off',
    'feature:administrative|saturation:-100|lightness:6',
    'feature:administrative.province|visibility:off',
    'feature:landscape|saturation:-100|lightness:42',
    'feature:poi|saturation:-100|lightness:28|visibility:simplified',
    'feature:poi.park|saturation:-100|lightness:34',
    'feature:road|saturation:-100|lightness:8',
    'feature:road.highway|saturation:-100|lightness:-10|visibility:simplified',
    'feature:road.arterial|saturation:-100|lightness:-2',
    'feature:road.local|saturation:-100|lightness:14',
    'feature:transit|saturation:-100|lightness:18|visibility:simplified',
    'feature:water|saturation:-100|lightness:16',
    'feature:water|element:labels|saturation:-100|lightness:4',
  ];

  @override
  MapProviderType get type => MapProviderType.google;

  @override
  String get nativeMapStyle => googleMapsLegacyNativeStyle;

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
    bool showMarker = true,
    String? customMarkerUrl = defaultStaticMapMarkerUrl,
    String fallbackUrl = 'https://picsum.photos/seed/nyc-map/1000/1000',
  }) {
    if (_apiKey.isEmpty) return fallbackUrl;
    final zoomValue = zoom == zoom.roundToDouble()
        ? zoom.round().toString()
        : zoom.toString();
    const maxDimension = 640;
    final resizeFactor = math.max(
      math.max(width / maxDimension, height / maxDimension),
      1,
    );
    final requestWidth = (width / resizeFactor).round();
    final requestHeight = (height / resizeFactor).round();

    final params = <String, List<String>>{
      'size': ['${requestWidth}x$requestHeight'],
      'center': ['$latitude,$longitude'],
      'zoom': [zoomValue],
      'scale': ['2'],
      'format': ['png'],
      'maptype': ['roadmap'],
      'key': [_apiKey],
      'style': _staticMapStyles,
    };
    if (showMarker) {
      final markerValue = customMarkerUrl == null || customMarkerUrl.isEmpty
          ? '$latitude,$longitude'
          : 'anchor:bottom|icon:$customMarkerUrl|$latitude,$longitude';
      params['markers'] = [markerValue];
    }

    final query = params.entries
        .expand(
          (entry) => entry.value.map(
            (value) =>
                '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
          ),
        )
        .join('&');

    return 'https://maps.googleapis.com/maps/api/staticmap?$query';
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
