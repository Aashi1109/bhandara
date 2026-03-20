class UserAuthMeta {
  UserAuthMeta({required this.provider});

  factory UserAuthMeta.fromJson(Map<String, dynamic> json) {
    return UserAuthMeta(provider: json['provider'] as String? ?? 'email');
  }

  final String provider;

  Map<String, dynamic> toJson() => {'provider': provider};
}

class NotificationPreferences {
  NotificationPreferences({
    this.events = true,
    this.chat = true,
    this.replies = false,
    this.reminders = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      events: json['events'] as bool? ?? true,
      chat: json['chat'] as bool? ?? true,
      replies: json['replies'] as bool? ?? false,
      reminders: json['reminders'] as bool? ?? true,
    );
  }

  final bool events;
  final bool chat;
  final bool replies;
  final bool reminders;

  Map<String, dynamic> toJson() => {
        'events': events,
        'chat': chat,
        'replies': replies,
        'reminders': reminders,
      };
}

class UserAddress {
  UserAddress({
    required this.label,
    this.latitude,
    this.longitude,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    final coordinates =
        (json['coordinates'] as Map?)?.cast<String, dynamic>() ?? const {};

    return UserAddress(
      label: json['address'] as String? ?? '',
      latitude:
          (json['latitude'] as num?)?.toDouble() ??
              (coordinates['latitude'] as num?)?.toDouble(),
      longitude:
          (json['longitude'] as num?)?.toDouble() ??
              (coordinates['longitude'] as num?)?.toDouble(),
    );
  }

  final String label;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
        'address': label,
        'coordinates': {
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      };
}

class UserMeta {
  UserMeta({
    this.auth,
    this.hasOnboarded = false,
    this.interests = const [],
    this.notificationPreferences,
    this.shareLocation,
  });

  factory UserMeta.fromJson(Map<String, dynamic> json) {
    return UserMeta(
      auth: json['auth'] != null
          ? UserAuthMeta.fromJson(json['auth'] as Map<String, dynamic>)
          : null,
      hasOnboarded: json['hasOnboarded'] as bool? ?? false,
      interests: (json['interests'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      notificationPreferences: json['notificationPreferences'] is Map
          ? NotificationPreferences.fromJson(
              (json['notificationPreferences'] as Map).cast<String, dynamic>(),
            )
          : null,
      shareLocation: json['shareLocation'] as bool?,
    );
  }

  final UserAuthMeta? auth;
  final bool hasOnboarded;
  final List<String> interests;
  final NotificationPreferences? notificationPreferences;
  final bool? shareLocation;

  Map<String, dynamic> toJson() {
    return {
      'auth': auth?.toJson(),
      'hasOnboarded': hasOnboarded,
      'interests': interests,
      if (notificationPreferences != null)
        'notificationPreferences': notificationPreferences!.toJson(),
      if (shareLocation != null) 'shareLocation': shareLocation,
    };
  }
}

class User {
  User({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.createdAt,
    this.meta,
    this.address,
    this.isSocialLogin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] != null
        ? UserMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : null;

    // avatarUrl: server stores it as profilePic JSONB {url: ...} or direct avatarUrl string
    String? avatarUrl = json['avatarUrl'] as String?;
    if (avatarUrl == null && json['media'] is Map) {
      final media = json['media'] as Map<String, dynamic>;
      avatarUrl = (media['publicUrl'] ?? media['url']) as String?;
    }
    if (avatarUrl == null && json['profilePic'] is Map) {
      avatarUrl =
      (json['profilePic'] as Map<String, dynamic>)['url'] as String?;
    }

    // isSocialLogin: derived from meta.auth.provider (not 'email' = social)
    final provider = meta?.auth?.provider ??
        (json['meta'] as Map<String, dynamic>?)?['provider'] as String?;
    final isSocialLogin =
        json['isSocialLogin'] as bool? ??
        (provider != null && provider != 'email' && provider.isNotEmpty);

    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      username: json['username'] as String?,
      avatarUrl: avatarUrl,
      bio: json['bio'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      meta: meta,
      address: json['address'] is Map
          ? UserAddress.fromJson((json['address'] as Map).cast<String, dynamic>())
          : null,
      isSocialLogin: isSocialLogin,
    );
  }

  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final DateTime? createdAt;
  final UserMeta? meta;
  final UserAddress? address;
  bool isSocialLogin;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'createdAt': createdAt?.toIso8601String(),
      'meta': meta?.toJson(),
      'address': address?.toJson(),
    };
  }
}
