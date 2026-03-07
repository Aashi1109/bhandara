class Thread {
  final String id;
  final String eventId;
  final String? type;
  final DateTime createdAt;

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
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

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
  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final String? type;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

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
    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] is String
          ? json['content'] as String
          : (json['content'] as Map<String, dynamic>)['text'] ?? '',
      type: json['type'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      senderName: json['sender']?['name'] as String?,
      senderAvatar: json['sender']?['avatarUrl'] as String?,
    );
  }

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
