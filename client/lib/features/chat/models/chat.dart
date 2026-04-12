enum MessageDeliveryStatus { pending, failed, sent }

enum ChatMessageLane { left, center, right }

enum ThreadMessageLane { left, center }

class Thread {
  Thread({
    required this.id,
    required this.eventId,
    this.type,
    this.title,
    this.parentId,
    this.isLocked = false,
    required this.createdAt,
    this.stats,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      type: json['type'] as String?,
      title: json['title'] as String?,
      parentId: json['parentId'] as String?,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      stats: json['stats'] is Map<String, dynamic>
          ? ThreadStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String eventId;
  final String? type;
  final String? title;
  final String? parentId;
  final bool isLocked;
  final DateTime createdAt;
  final ThreadStats? stats;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'type': type,
      'title': title,
      'parentId': parentId,
      'isLocked': isLocked,
      'createdAt': createdAt.toIso8601String(),
      'stats': stats?.toJson(),
    };
  }
}

class ThreadStats {
  ThreadStats({
    required this.reactionCount,
    required this.messageCount,
    required this.viewCount,
    required this.ratingCount,
    required this.ratingAverage,
  });

  factory ThreadStats.fromJson(Map<String, dynamic> json) {
    return ThreadStats(
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
    );
  }

  final int reactionCount;
  final int messageCount;
  final int viewCount;
  final int ratingCount;
  final double ratingAverage;

  Map<String, dynamic> toJson() {
    return {
      'reactionCount': reactionCount,
      'messageCount': messageCount,
      'viewCount': viewCount,
      'ratingCount': ratingCount,
      'ratingAverage': ratingAverage,
    };
  }
}

class Message {
  Message({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.content,
    this.type,
    this.parentId,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.media = const [],
    this.reactions = const [],
    this.children = const [],
    this.stats,
    this.localId,
    this.deliveryStatus = MessageDeliveryStatus.sent,
    this.retryMediaIds = const [],
    this.localPreviewPaths = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Server field: userId (not senderId)
    final senderId = (json['userId'] ?? json['senderId']) as String? ?? '';

    // content: IMessageContent = { text?, media?, links? } or plain string
    String content = '';
    final raw = json['content'];
    List<MessageMedia> media = const [];
    List<MessageReaction> reactions = const [];
    String sanitizeText(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.toLowerCase() == 'undefined' ||
            trimmed.toLowerCase() == 'null') {
          return '';
        }
        return value;
      }
      return '';
    }

    if (raw is String) {
      content = sanitizeText(raw);
    } else if (raw is Map) {
      content = sanitizeText(raw['text']);
      media = ((raw['media'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MessageMedia.fromJson(item.cast<String, dynamic>()))
          .toList();
    }

    reactions = ((json['reactions'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => MessageReaction.fromJson(item.cast<String, dynamic>()))
        .toList();

    // Sender info: server returns `user` object (not `sender`)
    final userObj = (json['user'] ?? json['sender']) as Map<String, dynamic>?;
    final String? senderName = userObj?['name'] as String?;
    // avatarUrl comes from user.profilePic.url or user.avatarUrl
    String? senderAvatar = userObj?['avatarUrl'] as String?;
    if (senderAvatar == null && userObj?['profilePic'] is Map) {
      senderAvatar =
          (userObj!['profilePic'] as Map<String, dynamic>)['url'] as String?;
    }

    final children = ((json['children'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Message.fromJson(item.cast<String, dynamic>()))
        .toList();

    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderId: senderId,
      content: content,
      type: json['type'] as String?,
      parentId: json['parentId'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      senderName: senderName,
      senderAvatar: senderAvatar,
      media: media,
      reactions: reactions,
      children: children,
      stats: json['stats'] is Map<String, dynamic>
          ? MessageStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
      deliveryStatus: MessageDeliveryStatus.sent,
      retryMediaIds: media
          .map((item) => item.id)
          .where((id) => id.isNotEmpty)
          .toList(),
      localPreviewPaths: const [],
    );
  }

  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final String? type;
  final String? parentId;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  final List<MessageMedia> media;
  final List<MessageReaction> reactions;
  final List<Message> children;
  final MessageStats? stats;
  final String? localId;
  final MessageDeliveryStatus deliveryStatus;
  final List<String> retryMediaIds;
  final List<String> localPreviewPaths;

  bool get isPending => deliveryStatus == MessageDeliveryStatus.pending;
  bool get hasFailed => deliveryStatus == MessageDeliveryStatus.failed;
  bool get isSystemLike => type == 'system' || type == 'notification';

  bool isCurrentUser(String? currentUserId) =>
      !isSystemLike && currentUserId != null && senderId == currentUserId;

  ChatMessageLane chatLaneFor(String? currentUserId) {
    if (isSystemLike) return ChatMessageLane.center;
    return isCurrentUser(currentUserId)
        ? ChatMessageLane.right
        : ChatMessageLane.left;
  }

  ThreadMessageLane threadLaneFor(String? currentUserId) {
    if (isSystemLike) return ThreadMessageLane.center;
    return ThreadMessageLane.left;
  }

  Message copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? content,
    String? type,
    String? parentId,
    DateTime? createdAt,
    String? senderName,
    String? senderAvatar,
    List<MessageMedia>? media,
    List<MessageReaction>? reactions,
    List<Message>? children,
    MessageStats? stats,
    String? localId,
    MessageDeliveryStatus? deliveryStatus,
    List<String>? retryMediaIds,
    List<String>? localPreviewPaths,
  }) {
    return Message(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      media: media ?? this.media,
      reactions: reactions ?? this.reactions,
      children: children ?? this.children,
      stats: stats ?? this.stats,
      localId: localId ?? this.localId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      retryMediaIds: retryMediaIds ?? this.retryMediaIds,
      localPreviewPaths: localPreviewPaths ?? this.localPreviewPaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'stats': stats?.toJson(),
      'localId': localId,
      'deliveryStatus': deliveryStatus.name,
      'retryMediaIds': retryMediaIds,
      'localPreviewPaths': localPreviewPaths,
      'reactions': reactions.map((item) => item.toJson()).toList(),
    };
  }
}

class MessageStats {
  MessageStats({
    required this.reactionCount,
    required this.replyCount,
    required this.viewCount,
    required this.ratingCount,
    required this.ratingAverage,
  });

  factory MessageStats.fromJson(Map<String, dynamic> json) {
    return MessageStats(
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
    );
  }

  final int reactionCount;
  final int replyCount;
  final int viewCount;
  final int ratingCount;
  final double ratingAverage;

  Map<String, dynamic> toJson() {
    return {
      'reactionCount': reactionCount,
      'replyCount': replyCount,
      'viewCount': viewCount,
      'ratingCount': ratingCount,
      'ratingAverage': ratingAverage,
    };
  }
}

class MessageMedia {
  MessageMedia({required this.id, required this.url, this.type});

  factory MessageMedia.fromJson(Map<String, dynamic> json) {
    return MessageMedia(
      id: json['id'] as String? ?? '',
      url: (json['publicUrl'] ?? json['url']) as String? ?? '',
      type: json['type'] as String?,
    );
  }

  final String id;
  final String url;
  final String? type;
}

class MessageReaction {
  MessageReaction({
    required this.id,
    required this.contentId,
    required this.emoji,
    required this.userId,
    this.user,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as String? ?? '',
      contentId: json['contentId'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      user: json['user'] is Map<String, dynamic>
          ? MessageReactionUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String contentId;
  final String emoji;
  final String userId;
  final MessageReactionUser? user;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'emoji': emoji,
      'userId': userId,
      'user': user?.toJson(),
    };
  }
}

class MessageReactionUser {
  MessageReactionUser({required this.id, this.name, this.avatarUrl});

  factory MessageReactionUser.fromJson(Map<String, dynamic> json) {
    String? avatarUrl = json['avatarUrl'] as String?;
    if (avatarUrl == null && json['profilePic'] is Map<String, dynamic>) {
      avatarUrl =
          (json['profilePic'] as Map<String, dynamic>)['url'] as String?;
    }

    return MessageReactionUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: avatarUrl,
    );
  }

  final String id;
  final String? name;
  final String? avatarUrl;

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'avatarUrl': avatarUrl};
  }
}
