class Thread {
  Thread({
    required this.id,
    required this.eventId,
    this.type,
    required this.createdAt,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      type: json['type'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String eventId;
  final String? type;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
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
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Server field: userId (not senderId)
    final senderId = (json['userId'] ?? json['senderId']) as String? ?? '';

    // content: IMessageContent = { text?, media?, links? } or plain string
    String content = '';
    final raw = json['content'];
    if (raw is String) {
      content = raw;
    } else if (raw is Map) {
      content = raw['text'] as String? ?? '';
    }

    // Sender info: server returns `user` object (not `sender`)
    final userObj = (json['user'] ?? json['sender']) as Map<String, dynamic>?;
    final String? senderName = userObj?['name'] as String?;
    // avatarUrl comes from user.profilePic.url or user.avatarUrl
    String? senderAvatar = userObj?['avatarUrl'] as String?;
    if (senderAvatar == null && userObj?['profilePic'] is Map) {
      senderAvatar =
          (userObj!['profilePic'] as Map<String, dynamic>)['url'] as String?;
    }

    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderId: senderId,
      content: content,
      type: json['type'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      senderName: senderName,
      senderAvatar: senderAvatar,
    );
  }

  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final String? type;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
