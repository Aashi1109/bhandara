import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/chat/models/chat.dart';

void main() {
  Message buildMessage({
    required String id,
    required String senderId,
    String? type,
  }) {
    return Message(
      id: id,
      threadId: 'thread-1',
      senderId: senderId,
      content: 'Hello',
      type: type,
      createdAt: DateTime.parse('2026-03-31T10:00:00Z'),
    );
  }

  test('chat lane uses right for current user and left for others', () {
    final ownMessage = buildMessage(id: 'm1', senderId: 'user-1');
    final otherMessage = buildMessage(id: 'm2', senderId: 'user-2');

    expect(ownMessage.chatLaneFor('user-1'), ChatMessageLane.right);
    expect(otherMessage.chatLaneFor('user-1'), ChatMessageLane.left);
  });

  test('system-like messages are centered in chat and threads', () {
    final systemMessage = buildMessage(id: 'm3', senderId: '', type: 'system');
    final notificationMessage = buildMessage(
      id: 'm4',
      senderId: '',
      type: 'notification',
    );

    expect(systemMessage.isSystemLike, isTrue);
    expect(notificationMessage.isSystemLike, isTrue);
    expect(systemMessage.chatLaneFor('user-1'), ChatMessageLane.center);
    expect(
      notificationMessage.threadLaneFor('user-1'),
      ThreadMessageLane.center,
    );
  });

  test('thread lane keeps user and other-user replies on the left', () {
    final ownReply = buildMessage(id: 'm5', senderId: 'user-1');
    final otherReply = buildMessage(id: 'm6', senderId: 'user-2');

    expect(ownReply.threadLaneFor('user-1'), ThreadMessageLane.left);
    expect(otherReply.threadLaneFor('user-1'), ThreadMessageLane.left);
  });
}
