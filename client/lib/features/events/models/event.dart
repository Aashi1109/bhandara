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
    this.createdAt,
    this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final timings = _asMap(json['timings']);
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now();
    if (timings != null) {
      startTime = _parseDateTime(timings['start']) ?? startTime;
      endTime = _parseDateTime(timings['end']) ?? endTime;
    }
    startTime = _parseDateTime(json['startTime']) ?? startTime;
    startTime = _parseDateTime(json['start']) ?? startTime;
    endTime = _parseDateTime(json['endTime']) ?? endTime;
    endTime = _parseDateTime(json['end']) ?? endTime;

    List<String>? participants;
    List<EventUser>? participantUsers;
    final rawParticipants = _asList(json['participants']);
    if (rawParticipants != null) {
      participantUsers = [];
      participants = [];
      for (final participant in rawParticipants) {
        final participantMap = _asMap(participant);
        final rawUser = participantMap != null && participantMap.containsKey('user')
            ? participantMap['user']
            : participant;

        if (rawUser is String && rawUser.isNotEmpty) {
          participants.add(rawUser);
          continue;
        }

        final userMap = _asMap(rawUser);
        final userId = _stringValue(userMap?['id']);
        if (userMap == null || userId == null || userId.isEmpty) {
          continue;
        }

        participantUsers.add(EventUser.fromJson(userMap));
        participants.add(userId);
      }
    }

    List<Media>? media;
    final rawMedia = _asList(json['media']);
    if (rawMedia != null) {
      media = rawMedia
          .map((item) => Media.tryFromJson(_asMap(item)))
          .whereType<Media>()
          .toList();
    }

    List<Tag>? tags;
    final rawTags = _asList(json['tags']);
    if (rawTags != null) {
      tags = rawTags
          .map((item) => Tag.tryFromJson(_asMap(item)))
          .whereType<Tag>()
          .toList();
    }

    final creator = EventUser.tryFromJson(_asMap(json['creator']));
    final verifiers = (_asList(json['verifiers']) ?? const [])
        .map((item) => EventVerifier.tryFromJson(_asMap(item)))
        .whereType<EventVerifier>()
        .toList();
    final stats = _asMap(json['stats']) != null
        ? EventStats.fromJson(_asMap(json['stats'])!)
        : null;
    final createdBy =
        _stringValue(json['createdBy']) ??
        _stringValue(_asMap(json['createdBy'])?['id']) ??
        creator?.id ??
        '';
    final location = Location.tryFromJson(_asMap(json['location'])) ??
        const Location(address: '');

    return Event(
      id: _stringValue(json['id']) ?? '',
      name: _stringValue(json['name']) ?? '',
      description: _stringValue(json['description']),
      status: _stringValue(json['status']) ?? 'DRAFT',
      type: _stringValue(json['type']) ?? 'PUBLIC',
      startTime: startTime,
      endTime: endTime,
      createdBy: createdBy,
      location: location,
      media: media,
      tags: tags,
      participants: participantUsers?.isNotEmpty == true ? participantUsers : participants,
      verifiers: verifiers,
      creator: creator,
      capacity: (json['capacity'] as num?)?.toInt(),
      stats: stats,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      createdAt: other.createdAt ?? createdAt,
      updatedAt: other.updatedAt ?? updatedAt,
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
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    String? avatarUrl = _stringValue(json['avatarUrl']);
    final profilePic = _asMap(json['profilePic']);
    if (avatarUrl == null && profilePic != null) {
      avatarUrl = _stringValue(profilePic['url']);
    }

    return EventUser(
      id: _stringValue(json['id']) ?? '',
      name: _stringValue(json['name']),
      avatarUrl: avatarUrl,
    );
  }

  static EventUser? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final id = _stringValue(json['id']);
    if (id == null || id.isEmpty) {
      return null;
    }
    return EventUser.fromJson(json);
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
    final userMap = _asMap(rawUser);
    final userId = _stringValue(rawUser) ?? _stringValue(userMap?['id']) ?? '';
    return EventVerifier(
      user: userMap != null
          ? EventUser.fromJson(userMap)
          : EventUser(id: userId, name: null, avatarUrl: null),
      verifiedAt: _parseDateTime(json['verifiedAt']),
    );
  }

  static EventVerifier? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final rawUser = json['user'];
    final userId =
        _stringValue(rawUser) ?? _stringValue(_asMap(rawUser)?['id']);
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return EventVerifier.fromJson(json);
  }

  final EventUser user;
  final DateTime? verifiedAt;
}

class Location {
  const Location({
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    double? lat = (json['latitude'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble();

    final coords = _asMap(json['coordinates']);
    if (lat == null && coords != null) {
      lat = (coords['latitude'] as num?)?.toDouble();
      lng = (coords['longitude'] as num?)?.toDouble();
    }

    return Location(
      address: _stringValue(json['address']) ?? '',
      latitude: lat,
      longitude: lng,
    );
  }

  static Location? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Location.fromJson(json);
  }

  final String address;
  final double? latitude;
  final double? longitude;
}

class Media {
  Media({required this.id, required this.url, required this.type});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: _stringValue(json['id']) ?? '',
      url: _stringValue(json['publicUrl']) ?? _stringValue(json['url']) ?? '',
      type: _stringValue(json['type']) ?? 'image',
    );
  }

  static Media? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final id = _stringValue(json['id']);
    final url = _stringValue(json['publicUrl']) ?? _stringValue(json['url']);
    if (id == null || id.isEmpty || url == null || url.isEmpty) {
      return null;
    }
    return Media.fromJson(json);
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
      id: _stringValue(json['id']) ?? '',
      name: _stringValue(json['name']) ?? '',
      value: _stringValue(json['value']),
      icon: _stringValue(json['icon']),
      color: _stringValue(json['color']),
      parentId: _stringValue(json['parentId']),
      hasChildren: json['hasChildren'] as bool? ?? false,
    );
  }

  static Tag? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final id = _stringValue(json['id']);
    final name = _stringValue(json['name']);
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    return Tag.fromJson(json);
  }

  final String id;
  final String name;
  final String? value;
  final String? icon;
  final String? color;
  final String? parentId;
  final bool hasChildren;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<dynamic>? _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return List<dynamic>.from(value);
  }
  return null;
}

String? _stringValue(dynamic value) {
  if (value is String) {
    return value;
  }
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  final raw = _stringValue(value);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}
