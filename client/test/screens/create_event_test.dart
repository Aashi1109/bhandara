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
    meta: UserMeta(interests: ['tag-1']),
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
        ChatAttachment(
          id: '3',
          mediaId: 'media-3',
          name: 'menu.pdf',
          localPath: '/tmp/menu.pdf',
          sizeBytes: 4096,
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
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create_event_attachment_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_attachment_2')),
      findsOneWidget,
    );
    expect(find.text('clip-two.mp4'), findsWidgets);
    expect(find.text('menu.pdf'), findsOneWidget);
    expect(find.text('Supporting media'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('create_event_attachment_1')),
      warnIfMissed: false,
    );
    await _settle(tester);

    expect(find.text('clip-two.mp4'), findsWidgets);
  });

  testWidgets('matches the canvas empty supporting media treatment', (
    tester,
  ) async {
    await _pumpCreateScreen(tester, user: testUser, scheduleSelected: false);

    expect(
      find.byKey(const ValueKey('create_event_supporting_media')),
      findsOneWidget,
    );
    expect(find.text('Bring the moment to life'), findsOneWidget);
    expect(find.text('Add photos, videos or PDFs · Optional'), findsOneWidget);
    expect(find.text('Supporting media'), findsNothing);
  });

  testWidgets('matches canvas field and category typography', (tester) async {
    await _pumpCreateScreen(tester, user: testUser, scheduleSelected: false);

    final eventNameLabel = tester.widget<Text>(find.text('Event name'));
    final startsLabel = tester.widget<Text>(find.text('Starts'));
    final visibilityLabel = tester.widget<Text>(find.text('Who can see this?'));
    final requiredLabel = tester.widget<Text>(find.text('Required'));
    final timePlaceholders = tester.widgetList<Text>(find.text('Choose time'));

    expect(eventNameLabel.style?.fontSize, 14);
    expect(eventNameLabel.style?.fontWeight, FontWeight.w700);
    expect(startsLabel.style?.fontSize, 14);
    expect(visibilityLabel.style?.fontSize, 14);
    expect(visibilityLabel.style?.fontWeight, FontWeight.w700);
    expect(requiredLabel.style?.fontSize, 12);
    expect(requiredLabel.style?.fontWeight, FontWeight.w600);
    expect(requiredLabel.style?.letterSpacing, 0);
    expect(timePlaceholders, hasLength(2));
    for (final placeholder in timePlaceholders) {
      expect(placeholder.style?.fontSize, 14);
      expect(placeholder.style?.fontWeight, FontWeight.w500);
    }
    expect(find.byType(ChoiceChip), findsNothing);
    final categoryList = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('create_event_category_list')),
    );
    expect(categoryList.scrollDirection, Axis.horizontal);
  });

  testWidgets('matches the narrow mobile layout without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpCreateScreen(tester, user: testUser);
    await tester.ensureVisible(
      find.byKey(const ValueKey('create_event_submit_button')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
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

    final titleField = find.text('e.g. Sunday supper club');
    final aboutLabel = find.text('What’s it about?');

    expect(
      tester.getTopLeft(aboutLabel).dy,
      greaterThan(tester.getTopLeft(titleField).dy),
    );
    expect(
      find.byKey(const ValueKey('create_event_hero_preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_date_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_start_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_event_end_field')),
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

    final start = DateTime.parse(payload!['startTime'] as String);
    final end = DateTime.parse(payload!['endTime'] as String);

    expect(end.isAfter(start), isTrue);
    expect(end.difference(start), lessThanOrEqualTo(const Duration(days: 7)));
  });

  testWidgets('submits guest capacity and keeps the event API type', (
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
    );

    await tester.enterText(find.byType(TextField).first, 'Community Supper');
    await tester.enterText(
      find.byType(TextField).at(1),
      'A shared table for the neighborhood.',
    );
    await tester.enterText(find.byType(TextField).at(2), '24');
    await _dragLaunch(tester);
    await _settle(tester);

    expect(payload, isNotNull);
    expect(payload!['capacity'], 24);
    expect(payload!['type'], 'custom');
  });

  testWidgets('rejects invalid guest capacity', (tester) async {
    var createCalls = 0;

    await _pumpCreateScreen(
      tester,
      user: testUser,
      createEventRequest: (_) async => createCalls += 1,
    );

    await tester.enterText(find.byType(TextField).first, 'Small Supper');
    await tester.enterText(
      find.byType(TextField).at(1),
      'A deliberately small gathering.',
    );
    await tester.enterText(find.byType(TextField).at(2), '0');
    await _dragLaunch(tester);
    await _settle(tester);

    expect(createCalls, 0);
    expect(find.text('Enter a valid guest capacity.'), findsOneWidget);
  });

  testWidgets('save draft sends draft status', (tester) async {
    Map<String, dynamic>? payload;

    await _pumpCreateScreen(
      tester,
      user: testUser,
      createEventRequest: (data) async {
        payload = data;
        throw Exception('skip navigation');
      },
    );

    await tester.enterText(find.byType(TextField).first, 'Draft Supper');
    await tester.enterText(
      find.byType(TextField).at(1),
      'A draft gathering description.',
    );
    final saveDraft = find.byKey(
      const ValueKey('create_event_save_draft_button'),
    );
    await tester.ensureVisible(saveDraft);
    await tester.tap(saveDraft);
    await _settle(tester);

    expect(payload, isNotNull);
    expect(payload!['status'], 'draft');
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
    final start = DateTime.parse(payload!['startTime'] as String);
    final end = DateTime.parse(payload!['endTime'] as String);
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
  bool scheduleSelected = true,
}) async {
  final selectedStart =
      initialStartAt ??
      (scheduleSelected ? DateTime.now().add(const Duration(days: 1)) : null);
  final selectedEnd =
      initialEndAt ?? selectedStart?.add(const Duration(hours: 2));
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
          initialStartAt: selectedStart,
          initialEndAt: selectedEnd,
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
  final submit = find.byKey(const ValueKey('create_event_submit_button'));
  expect(submit, findsOneWidget);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
}

class _TestUserProfile extends UserProfile {
  _TestUserProfile(this.user);

  final User user;

  @override
  FutureOr<User?> build() async => user;
}
