import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/chat/models/chat_attachment.dart';
import 'package:foody_mobile/features/events/models/event.dart';
import 'package:foody_mobile/shared/providers/tag.dart';
import 'package:foody_mobile/features/profile/models/user.dart';
import 'package:foody_mobile/shared/providers/user.dart';
import 'package:foody_mobile/features/events/screens/create_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    id: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
    address: UserAddress(
      label: 'Base Location',
      latitude: 21.1458,
      longitude: 79.0882,
    ),
  );

  testWidgets('renders multiple upload pills and updates hero preview', (
    tester,
  ) async {
    await _pumpCreateScreen(
      tester,
      user: testUser,
      initialAttachments: [
        ChatAttachment(
          id: '1',
          mediaId: 'media-1',
          name: 'clip-one.mp4',
          localPath: '/tmp/clip-one.mp4',
          sizeBytes: 1024,
          isVideo: true,
        ),
        ChatAttachment(
          id: '2',
          mediaId: 'media-2',
          name: 'clip-two.mp4',
          localPath: '/tmp/clip-two.mp4',
          sizeBytes: 2048,
          isVideo: true,
        ),
      ],
      initialSelectedAttachmentIndex: 1,
    );

    expect(
      find.byKey(const ValueKey('create_event_hero_preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_attachment_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_attachment_1')),
      findsOneWidget,
    );
    expect(find.text('clip-two.mp4'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('create_event_attachment_0')),
      warnIfMissed: false,
    );
    await _settle(tester);

    expect(find.text('clip-one.mp4'), findsWidgets);
  });

  testWidgets('failed uploads stay visible and block create', (tester) async {
    var createCalls = 0;

    await _pumpCreateScreen(
      tester,
      user: testUser,
      createEventRequest: (_) async => createCalls += 1,
      initialAttachments: [
        ChatAttachment(
          id: 'broken',
          name: 'broken.mp4',
          localPath: '/tmp/broken.mp4',
          sizeBytes: 500,
          isVideo: true,
          hasFailed: true,
        ),
      ],
    );
    await tester.enterText(find.byType(TextField).first, 'Night Market');
    await _settle(tester);

    await _dragLaunch(tester);
    await _settle(tester);

    expect(createCalls, 0);
  });

  testWidgets('focuses title when submit fails validation', (tester) async {
    await _pumpCreateScreen(tester, user: testUser);

    await _dragLaunch(tester);
    await _settle(tester);

    expect(find.text('Please enter an event title.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('keeps about-event order and submits typed ISO datetimes', (
    tester,
  ) async {
    Map<String, dynamic>? payload;

    await _pumpCreateScreen(
      tester,
      user: testUser,
      createEventRequest: (data) async {
        payload = data;
        throw Exception('skip navigation');
      },
      resolveTagIds: (_) async => ['tag-1'],
    );

    final titleField = find.text('Event Title (e.g. Midnight Pizza)');
    final aboutLabel = find.text('ABOUT EVENT');

    expect(
      tester.getTopLeft(aboutLabel).dy,
      greaterThan(tester.getTopLeft(titleField).dy),
    );
    expect(
      find.byKey(const ValueKey('create_event_hero_preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_current_location_action')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'Sunset Dinner');
    await tester.enterText(find.byType(TextField).at(1), 'Chef tasting menu.');
    await _dragLaunch(tester);
    await _settle(tester);

    expect(payload, isNotNull);
    expect(payload!['name'], 'Sunset Dinner');
    expect(payload!['description'], 'Chef tasting menu.');
    expect(payload!.containsKey('status'), isFalse);

    final timings = payload!['timings'] as Map<String, dynamic>;
    final start = DateTime.parse(timings['start'] as String);
    final end = DateTime.parse(timings['end'] as String);

    expect(end.isAfter(start), isTrue);
    expect(end.difference(start), lessThanOrEqualTo(const Duration(days: 7)));
  });

  testWidgets('edit mode submits update request with prefilled values', (
    tester,
  ) async {
    String? updatedId;
    Map<String, dynamic>? updatedPayload;
    final now = DateTime.now();
    final futureStart = now.add(const Duration(days: 2));
    final futureEnd = futureStart.add(const Duration(hours: 2));

    final initialEvent = Event(
      id: 'event-1',
      name: 'Original Event',
      description: 'Original description',
      status: 'draft',
      type: 'custom',
      startTime: futureStart,
      endTime: futureEnd,
      createdBy: testUser.id,
      location: const Location(
        address: 'Initial address',
        latitude: 21.1458,
        longitude: 79.0882,
      ),
      tags: [Tag(id: 'tag-1', name: 'Community')],
    );

    await _pumpCreateScreen(
      tester,
      user: testUser,
      initialEvent: initialEvent,
      updateEventRequest: (eventId, data) async {
        updatedId = eventId;
        updatedPayload = data;
        return initialEvent.copyWith(name: data['name'] as String);
      },
    );

    expect(find.text('Edit Event'), findsOneWidget);
    expect(find.text('Original Event'), findsOneWidget);
    expect(find.text('Original description'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Updated Event');
    await _dragLaunch(tester);
    await _settle(tester);

    expect(updatedId, 'event-1');
    expect(updatedPayload, isNotNull);
    expect(updatedPayload!['name'], 'Updated Event');
  });

  testWidgets('allows ongoing event payloads when end time is still future', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    final now = DateTime.now();

    await _pumpCreateScreen(
      tester,
      user: testUser,
      initialStartAt: now.subtract(const Duration(hours: 1)),
      initialEndAt: now.add(const Duration(hours: 1)),
      createEventRequest: (data) async {
        payload = data;
        throw Exception('skip navigation');
      },
      resolveTagIds: (_) async => ['tag-1'],
    );

    await tester.enterText(find.byType(TextField).first, 'Live Community Meal');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Serving right now for anyone nearby.',
    );
    await _dragLaunch(tester);
    await _settle(tester);

    expect(payload, isNotNull);
    final timings = payload!['timings'] as Map<String, dynamic>;
    final start = DateTime.parse(timings['start'] as String);
    final end = DateTime.parse(timings['end'] as String);
    expect(start.isBefore(DateTime.now()), isTrue);
    expect(end.isAfter(DateTime.now()), isTrue);
  });
}

Future<void> _pumpCreateScreen(
  WidgetTester tester, {
  required User user,
  Event? initialEvent,
  Future<void> Function(Map<String, dynamic> data)? createEventRequest,
  Future<Event?> Function(String eventId, Map<String, dynamic> data)?
  updateEventRequest,
  Future<List<String>> Function(User user)? resolveTagIds,
  List<ChatAttachment>? initialAttachments,
  int initialSelectedAttachmentIndex = 0,
  DateTime? initialStartAt,
  DateTime? initialEndAt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(() => _TestUserProfile(user)),
        tagsProvider(
          rootOnly: true,
        ).overrideWith((_) async => [Tag(id: 'tag-1', name: 'Community')]),
      ],
      child: MaterialApp(
        home: CreateEventScreen(
          initialEvent: initialEvent,
          createEventRequest: createEventRequest,
          updateEventRequest: updateEventRequest,
          resolveTagIds: resolveTagIds,
          initialAttachments: initialAttachments,
          initialSelectedAttachmentIndex: initialSelectedAttachmentIndex,
          initialStartAt: initialStartAt,
          initialEndAt: initialEndAt,
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 4));
}

Future<void> _dragLaunch(WidgetTester tester) async {
  final slider = find.byKey(const ValueKey('create_event_launch_slider'));
  expect(slider, findsOneWidget);
  await tester.drag(slider, const Offset(320, 0));
}

class _TestUserProfile extends UserProfile {
  _TestUserProfile(this.user);

  final User user;

  @override
  FutureOr<User?> build() async => user;
}
