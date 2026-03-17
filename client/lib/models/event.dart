class Event {
  Event({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    required this.location,
    this.media,
    this.tags,
    this.participants,
    this.capacity,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // timings: { start, end } — server shape
    final timings = json['timings'] as Map<String, dynamic>?;
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now();
    if (timings != null) {
      if (timings['start'] != null) {
        startTime = DateTime.tryParse(timings['start'] as String) ?? startTime;
      }
      if (timings['end'] != null) {
        endTime = DateTime.tryParse(timings['end'] as String) ?? endTime;
      }
    }

    // participants: [{user: string|object, status: string}] — extract user IDs
    List<String>? participants;
    if (json['participants'] != null) {
      participants = (json['participants'] as List).map((p) {
        if (p is Map) {
          final user = p['user'];
          return user is Map ? user['id'] as String : user as String;
        }
        return p as String;
      }).toList();
    }

    // media: may be string IDs or full objects
    List<Media>? media;
    if (json['media'] != null) {
      media = (json['media'] as List).whereType<Map<String, dynamic>>().map(
          Media.fromJson).toList();
    }

    // tags: may be string IDs or full objects
    List<Tag>? tags;
    if (json['tags'] != null) {
      tags = (json['tags'] as List).whereType<Map<String, dynamic>>().map(
          Tag.fromJson).toList();
    }

    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      type: json['type'] as String? ?? 'PUBLIC',
      startTime: startTime,
      endTime: endTime,
      createdBy: json['createdBy'] as String,
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      media: media,
      tags: tags,
      participants: participants,
      capacity: json['capacity'] as int?,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String status;
  final String type;
  final DateTime startTime;
  final DateTime endTime;
  final String createdBy;
  final Location location;
  final List<Media>? media;
  final List<Tag>? tags;
  final List<String>? participants;
  final int? capacity;
}

class Location {
  Location({
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    // Server ILocation: { address, latitude?, longitude? }
    // Also handles nested coordinates: { coordinates: { latitude, longitude } }
    double? lat = (json['latitude'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble();

    if (lat == null && json['coordinates'] is Map) {
      final coords = json['coordinates'] as Map<String, dynamic>;
      lat = (coords['latitude'] as num?)?.toDouble();
      lng = (coords['longitude'] as num?)?.toDouble();
    }

    return Location(
      address: json['address'] as String? ?? '',
      latitude: lat,
      longitude: lng,
    );
  }

  final String address;
  final double? latitude;
  final double? longitude;
}

class Media {
  Media({required this.id, required this.url, required this.type});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] as String,
      url: (json['publicUrl'] ?? json['url']) as String,
      type: json['type'] as String? ?? 'image',
    );
  }

  final String id;
  final String url;
  final String type;
}

class Tag {
  Tag({
    required this.id,
    required this.name,
    this.value,
    this.icon,
    this.color,
    this.parentId,
    this.hasChildren = false,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      parentId: json['parentId'] as String?,
      hasChildren: json['hasChildren'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String? value;
  final String? icon;
  final String? color;
  final String? parentId;
  final bool hasChildren;
}
