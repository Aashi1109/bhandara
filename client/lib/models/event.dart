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
    this.verifiers,
    this.creator,
    this.capacity,
    this.stats,
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
    List<EventUser>? participantUsers;
    if (json['participants'] != null) {
      participantUsers = [];
      participants = (json['participants'] as List).map((p) {
        if (p is Map) {
          final user = p['user'];
          if (user is Map<String, dynamic>) {
            participantUsers!.add(EventUser.fromJson(user));
            return user['id'] as String;
          }
          return user as String;
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

    final creator = json['creator'] is Map<String, dynamic>
        ? EventUser.fromJson(json['creator'] as Map<String, dynamic>)
        : null;
    final verifiers = (json['verifiers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EventVerifier.fromJson)
        .toList();
    final stats = json['stats'] is Map<String, dynamic>
        ? EventStats.fromJson(json['stats'] as Map<String, dynamic>)
        : null;

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
      participants: participantUsers?.isNotEmpty == true ? participantUsers : participants,
      verifiers: verifiers,
      creator: creator,
      capacity: json['capacity'] as int?,
      stats: stats,
    );
  }

  Event copyWith({
    String? id,
    String? name,
    String? description,
    String? status,
    String? type,
    DateTime? startTime,
    DateTime? endTime,
    String? createdBy,
    Location? location,
    List<Media>? media,
    List<Tag>? tags,
    List<dynamic>? participants,
    List<EventVerifier>? verifiers,
    EventUser? creator,
    int? capacity,
    EventStats? stats,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdBy: createdBy ?? this.createdBy,
      location: location ?? this.location,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      participants: participants ?? this.participants,
      verifiers: verifiers ?? this.verifiers,
      creator: creator ?? this.creator,
      capacity: capacity ?? this.capacity,
      stats: stats ?? this.stats,
    );
  }

  Event merge(Event other) {
    return copyWith(
      id: other.id,
      name: other.name,
      description: other.description ?? description,
      status: other.status,
      type: other.type,
      startTime: other.startTime,
      endTime: other.endTime,
      createdBy: other.createdBy,
      location: other.location,
      media: other.media ?? media,
      tags: other.tags ?? tags,
      participants: other.participants ?? participants,
      verifiers: other.verifiers ?? verifiers,
      creator: other.creator ?? creator,
      capacity: other.capacity ?? capacity,
      stats: other.stats ?? stats,
    );
  }

  bool get hasPreviewData =>
      (media?.isNotEmpty ?? false) ||
      (tags?.isNotEmpty ?? false) ||
      stats != null;

  bool get hasFullDetail =>
      description != null ||
      creator != null ||
      (participants?.isNotEmpty ?? false) ||
      (verifiers?.isNotEmpty ?? false);

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
  final List<dynamic>? participants;
  final List<EventVerifier>? verifiers;
  final EventUser? creator;
  final int? capacity;
  final EventStats? stats;
}

class EventStats {
  EventStats({
    required this.reactionCount,
    required this.threadCount,
    required this.participantCount,
    required this.verifierCount,
    required this.mediaCount,
    required this.tagCount,
    required this.viewCount,
    required this.ratingCount,
    required this.ratingAverage,
  });

  factory EventStats.fromJson(Map<String, dynamic> json) {
    return EventStats(
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      threadCount: (json['threadCount'] as num?)?.toInt() ?? 0,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      verifierCount: (json['verifierCount'] as num?)?.toInt() ?? 0,
      mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
      tagCount: (json['tagCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
    );
  }

  final int reactionCount;
  final int threadCount;
  final int participantCount;
  final int verifierCount;
  final int mediaCount;
  final int tagCount;
  final int viewCount;
  final int ratingCount;
  final double ratingAverage;
}

class EventUser {
  EventUser({
    required this.id,
    this.name,
    this.avatarUrl,
  });

  factory EventUser.fromJson(Map<String, dynamic> json) {
    String? avatarUrl = json['avatarUrl'] as String?;
    if (avatarUrl == null && json['profilePic'] is Map) {
      avatarUrl =
          (json['profilePic'] as Map<String, dynamic>)['url'] as String?;
    }

    return EventUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatarUrl: avatarUrl,
    );
  }

  final String id;
  final String? name;
  final String? avatarUrl;
}

class EventVerifier {
  EventVerifier({
    required this.user,
    this.verifiedAt,
  });

  factory EventVerifier.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return EventVerifier(
      user: rawUser is Map<String, dynamic>
          ? EventUser.fromJson(rawUser)
          : EventUser(id: rawUser as String, name: null, avatarUrl: null),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
    );
  }

  final EventUser user;
  final DateTime? verifiedAt;
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
