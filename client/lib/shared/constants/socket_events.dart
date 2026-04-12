class SocketEvents {
  // Join/Leave
  static const String joinRoom = 'join:room';
  static const String leaveRoom = 'leave:room';

  // EVENTs
  static const String eventCreate = 'event:create';
  static const String eventUpdate = 'event:update';
  static const String eventDelete = 'event:delete';

  // THREADs
  static const String threadCreate = 'thread:create';
  static const String threadUpdate = 'thread:update';
  static const String threadDelete = 'thread:delete';
  static const String threadLock = 'thread:lock';
  static const String threadUnlock = 'thread:unlock';

  // MESSAGEs
  static const String messageCreate = 'message:create';
  static const String messageUpdate = 'message:update';
  static const String messageDelete = 'message:delete';

  // REACTIONs
  static const String reactionCreate = 'reaction:create';
  static const String reactionUpdate = 'reaction:update';
  static const String reactionDelete = 'reaction:delete';

  static const String userUpdate = 'user:update';
  static const String explore = 'explore';
}
