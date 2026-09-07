class SavedEntitySummary {
  SavedEntitySummary({
    required this.entityType,
    required this.entityId,
    required this.saved,
    required this.saveCount,
    this.savedAt,
  });

  factory SavedEntitySummary.fromJson(Map<String, dynamic> json) {
    return SavedEntitySummary(
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      saved: json['saved'] as bool? ?? false,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      savedAt: json['savedAt'] != null
          ? DateTime.tryParse(json['savedAt'] as String)
          : null,
    );
  }

  final String entityType;
  final String entityId;
  final bool saved;
  final int saveCount;
  final DateTime? savedAt;
}
