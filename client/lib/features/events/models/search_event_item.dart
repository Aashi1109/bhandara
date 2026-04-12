import './event.dart';
import '../../search/services/search.dart';

class SearchEventItem {
  SearchEventItem({
    required this.id,
    required this.name,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.status,
    this.type,
    this.imageUrl,
  });

  factory SearchEventItem.fromSearchResult(SearchResult result) {
    final metadata = result.metadata ?? const <String, dynamic>{};
    final locationData = metadata['location'] as Map<String, dynamic>? ?? const {};
    final timings = metadata['timings'] as Map<String, dynamic>? ?? const {};

    return SearchEventItem(
      id: result.id,
      name: result.title,
      location: Location.fromJson(locationData),
      startTime: DateTime.tryParse(timings['start'] as String? ?? '') ??
          DateTime.now(),
      endTime:
          DateTime.tryParse(timings['end'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(
            metadata['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      status: metadata['status'] as String?,
      type: metadata['type'] as String?,
      imageUrl: result.imageUrl,
    );
  }

  factory SearchEventItem.fromEvent(Event event) {
    final previewImage = event.media?.isNotEmpty == true ? event.media!.first.url : null;

    return SearchEventItem(
      id: event.id,
      name: event.name,
      location: event.location,
      startTime: event.startTime,
      endTime: event.endTime,
      createdAt: event.createdAt ?? DateTime.now(),
      status: event.status,
      type: event.type,
      imageUrl: previewImage,
    );
  }

  factory SearchEventItem.fromJson(Map<String, dynamic> json) {
    return SearchEventItem(
      id: json['id'] as String,
      name: json['name'] as String,
      location: Location.fromJson(
        (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] as String?,
      type: json['type'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final String id;
  final String name;
  final Location location;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;
  final String? status;
  final String? type;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': {
        'address': location.address,
        if (location.latitude != null) 'latitude': location.latitude,
        if (location.longitude != null) 'longitude': location.longitude,
      },
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'type': type,
      'imageUrl': imageUrl,
    };
  }
}
