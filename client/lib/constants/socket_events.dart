class SocketEvents {
  // Join/Leave
  static const String joinRoom = 'join:room';
  static const String leaveRoom = 'leave:room';

  // EVENTs
  static const String eventCreated = 'event:created';
  static const String eventUpdated = 'event:updated';
  static const String eventDeleted = 'event:deleted';

  // THREADs
  static const String threadCreated = 'thread:created';
  static const String threadUpdated = 'thread:updated';
  static const String threadDeleted = 'thread:deleted';
  static const String threadLocked = 'thread:locked';
  static const String threadUnlocked = 'thread:unlocked';

  // MESSAGEs
  static const String messageCreated = 'message:created';
  static const String messageUpdated = 'message:updated';
  static const String messageDeleted = 'message:deleted';

  // REACTIONs
  static const String reactionCreated = 'reaction:created';
  static const String reactionDeleted = 'reaction:deleted';

  static const String userUpdated = 'user:updated';
  static const String explore = 'explore';
}
