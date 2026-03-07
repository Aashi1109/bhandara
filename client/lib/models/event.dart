class Event {
  final String id;
  final String name;
  final String? description;
  final String status;
  final String visibility;
  final DateTime startTime;
  final DateTime endTime;
  final String createdBy;
  final Location location;
  final List<Media>? media;
  final List<Tag>? tags;

  Event({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.visibility,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    required this.location,
    this.media,
    this.tags,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      visibility: json['visibility'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      createdBy: json['createdBy'] as String,
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      media: json['media'] != null
          ? (json['media'] as List)
                .map((m) => Media.fromJson(m as Map<String, dynamic>))
                .toList()
          : null,
      tags: json['tags'] != null
          ? (json['tags'] as List)
                .map((t) => Tag.fromJson(t as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}

class Location {
  final double latitude;
  final double longitude;
  final String address;

  Location({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
    );
  }
}

class Media {
  final String id;
  final String url;
  final String type;

  Media({required this.id, required this.url, required this.type});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] as String,
      url: json['url'] as String,
      type: json['type'] as String,
    );
  }
}

class Tag {
  final String id;
  final String name;

  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(id: json['id'] as String, name: json['name'] as String);
  }
}
