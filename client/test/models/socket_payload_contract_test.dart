import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/models/chat.dart';
import 'package:foody_mobile/models/event.dart';

void main() {
  group('Socket payload contracts', () {
    test(
      'message payload emitted by the server parses with current client models',
      () {
        final payload = <String, dynamic>{
          'id': 'message-1',
          'threadId': 'thread-1',
          'userId': 'user-1',
          'content': {
            'text': 'Fresh batch is ready',
            'media': [
              {
                'id': 'media-1',
                'publicUrl': 'https://cdn.example.com/message-1.jpg',
                'type': 'image',
              },
            ],
          },
          'parentId': null,
          'createdAt': '2026-04-05T10:00:00.000Z',
          'user': {
            'id': 'user-1',
            'name': 'Ashish',
            'profilePic': {'url': 'https://cdn.example.com/avatar.jpg'},
          },
          'reactions': [
            {
              'id': 'reaction-1',
              'contentId': 'messages/message-1',
              'emoji': '🔥',
              'userId': 'user-2',
              'user': {
                'id': 'user-2',
                'name': 'Guest',
                'profilePic': {'url': 'https://cdn.example.com/guest.jpg'},
              },
            },
          ],
          'children': [
            {
              'id': 'reply-1',
              'threadId': 'thread-1',
              'userId': 'user-2',
              'content': 'On my way',
              'parentId': 'message-1',
              'createdAt': '2026-04-05T10:05:00.000Z',
            },
          ],
          'stats': {
            'reactionCount': 1,
            'replyCount': 1,
            'viewCount': 12,
            'ratingCount': 0,
            'ratingAverage': 0,
          },
        };

        final message = Message.fromJson(payload);

        expect(message.id, 'message-1');
        expect(message.threadId, 'thread-1');
        expect(message.senderId, 'user-1');
        expect(message.content, 'Fresh batch is ready');
        expect(message.media, hasLength(1));
        expect(
          message.media.first.url,
          'https://cdn.example.com/message-1.jpg',
        );
        expect(message.senderName, 'Ashish');
        expect(message.senderAvatar, 'https://cdn.example.com/avatar.jpg');
        expect(message.reactions, hasLength(1));
        expect(
          message.reactions.first.user?.avatarUrl,
          'https://cdn.example.com/guest.jpg',
        );
        expect(message.children, hasLength(1));
        expect(message.children.first.parentId, 'message-1');
        expect(message.stats?.replyCount, 1);
      },
    );

    test(
      'event payload emitted by the server parses with current client models',
      () {
        final payload = <String, dynamic>{
          'id': 'event-1',
          'name': 'Street Lunch',
          'description': 'Community meal',
          'status': 'ACTIVE',
          'type': 'PUBLIC',
          'createdBy': {'id': 'user-1'},
          'location': {
            'address': 'Main Square',
            'coordinates': {'latitude': 21.1458, 'longitude': 79.0882},
          },
          'timings': {
            'start': '2026-04-05T10:00:00.000Z',
            'end': '2026-04-05T12:00:00.000Z',
          },
          'media': [
            {
              'id': 'media-1',
              'publicUrl': 'https://cdn.example.com/event-1.jpg',
              'type': 'image',
            },
          ],
          'tags': [
            {'id': 'tag-1', 'name': 'community'},
          ],
          'participants': [
            {
              'user': {
                'id': 'user-2',
                'name': 'Guest',
                'profilePic': {'url': 'https://cdn.example.com/guest.jpg'},
              },
            },
          ],
          'verifiers': [
            {
              'user': {'id': 'user-3', 'name': 'Verifier'},
              'verifiedAt': '2026-04-05T09:50:00.000Z',
            },
          ],
          'creator': {
            'id': 'user-1',
            'name': 'Host',
            'profilePic': {'url': 'https://cdn.example.com/host.jpg'},
          },
          'stats': {
            'reactionCount': 2,
            'threadCount': 1,
            'participantCount': 1,
            'verifierCount': 1,
            'mediaCount': 1,
            'tagCount': 1,
            'viewCount': 10,
            'ratingCount': 2,
            'ratingAverage': 4.5,
          },
        };

        final event = Event.fromJson(payload);

        expect(event.id, 'event-1');
        expect(event.createdBy, 'user-1');
        expect(event.location.latitude, closeTo(21.1458, 0.0001));
        expect(event.location.longitude, closeTo(79.0882, 0.0001));
        expect(event.media, hasLength(1));
        expect(event.tags, hasLength(1));
        expect(event.participants, hasLength(1));
        expect(
          (event.participants!.first as EventUser).avatarUrl,
          'https://cdn.example.com/guest.jpg',
        );
        expect(event.verifiers, hasLength(1));
        expect(event.creator?.avatarUrl, 'https://cdn.example.com/host.jpg');
        expect(event.stats?.participantCount, 1);
      },
    );

    test(
      'reaction payload emitted by the server parses with current client models',
      () {
        final reaction = MessageReaction.fromJson({
          'id': 'reaction-1',
          'contentId': 'messages/message-1',
          'emoji': '🔥',
          'userId': 'user-2',
          'user': {
            'id': 'user-2',
            'name': 'Guest',
            'profilePic': {'url': 'https://cdn.example.com/guest.jpg'},
          },
        });

        expect(reaction.id, 'reaction-1');
        expect(reaction.contentId, 'messages/message-1');
        expect(reaction.emoji, '🔥');
        expect(reaction.user?.avatarUrl, 'https://cdn.example.com/guest.jpg');
      },
    );
  });
}
