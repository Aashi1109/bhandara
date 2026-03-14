class MapAddress {
  MapAddress({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.raw,
  });

  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? placeId;
  final Map<String, dynamic>? raw;
}

class MapSearchSuggestion {
  MapSearchSuggestion({
    required this.id,
    required this.title,
    this.subtitle,
    this.latitude,
    this.longitude,
    this.raw,
  });

  final String id;
  final String title;
  final String? subtitle;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? raw;
}
