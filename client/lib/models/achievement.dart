class Achievement {
  Achievement({
    required this.id,
    required this.userId,
    required this.key,
    required this.title,
    required this.description,
    required this.unlockedAt,
    this.icon,
    this.metadata = const {},
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      unlockedAt:
          DateTime.tryParse(json['unlockedAt'] as String? ?? '') ??
          DateTime.now(),
      icon: json['icon'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String id;
  final String userId;
  final String key;
  final String title;
  final String description;
  final DateTime unlockedAt;
  final String? icon;
  final Map<String, dynamic> metadata;
}
