class UserAuthMeta {
  UserAuthMeta({required this.provider});
  factory UserAuthMeta.fromJson(Map<String, dynamic> json) {
    return UserAuthMeta(provider: json['provider'] as String? ?? 'email');
  }
  final String provider;

  Map<String, dynamic> toJson() => {'provider': provider};
}

class UserMeta {
  UserMeta({this.auth, this.hasOnboarded = false});
  factory UserMeta.fromJson(Map<String, dynamic> json) {
    return UserMeta(
      auth: json['auth'] != null
          ? UserAuthMeta.fromJson(json['auth'] as Map<String, dynamic>)
          : null,
      hasOnboarded: json['hasOnboarded'] as bool? ?? false,
    );
  }
  final UserAuthMeta? auth;
  final bool hasOnboarded;

  Map<String, dynamic> toJson() {
    return {'auth': auth?.toJson(), 'hasOnboarded': hasOnboarded};
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
    this.isSocialLogin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      meta: json['meta'] != null ? UserMeta.fromJson(json['meta']) : null,
      isSocialLogin: json['isSocialLogin'] as bool? ?? false,
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
    };
  }
}
