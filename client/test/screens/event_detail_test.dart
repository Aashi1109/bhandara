import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/models/event.dart';
import 'package:foody_mobile/features/events/screens/event_detail.dart';
import 'package:foody_mobile/shared/services/api.dart';
import 'package:foody_mobile/shared/widgets/skeleton.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = apiService.dio.httpClientAdapter;
    apiService.dio.httpClientAdapter = _FakeHttpClientAdapter();
  });

  tearDown(() {
    apiService.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets('collapses hero and navigates multi-media carousel', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final event = Event(
      id: 'event-1',
      name: 'Street Food Social',
      description: 'A long dinner table with rotating chefs.',
      status: 'upcoming',
      type: 'PUBLIC',
      startTime: DateTime(2026, 3, 20, 19),
      endTime: DateTime(2026, 3, 20, 22),
      createdBy: 'host-1',
      location: const Location(address: 'Main Square'),
      media: [
        Media(id: 'media-1', url: 'https://example.com/1.jpg', type: 'image'),
        Media(id: 'media-2', url: 'https://example.com/2.jpg', type: 'image'),
        Media(id: 'media-3', url: 'https://example.com/3.jpg', type: 'image'),
      ],
      tags: [Tag(id: 'tag-1', name: 'Street Food')],
      verifiers: [
        EventVerifier(
          user: EventUser(id: 'verifier-1', name: 'Riya'),
        ),
      ],
      creator: EventUser(id: 'host-1', name: 'Ash'),
      stats: EventStats(
        reactionCount: 0,
        threadCount: 0,
        participantCount: 0,
        verifierCount: 1,
        mediaCount: 3,
        tagCount: 1,
        viewCount: 42,
        ratingCount: 8,
        ratingAverage: 4.6,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EventDetailScreen(id: event.id, initialEvent: event),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Minimize hero header'), findsNothing);
    expect(find.bySemanticsLabel('Expand hero header'), findsOneWidget);
    expect(find.text('42 views'), findsOneWidget);
    expect(find.byKey(const ValueKey('hero-carousel-prev')), findsNothing);
    expect(find.byKey(const ValueKey('hero-carousel-next')), findsOneWidget);

    await _triggerTap(tester, find.byKey(const ValueKey('hero-carousel-next')));

    expect(find.bySemanticsLabel('Expand hero header'), findsOneWidget);
    expect(find.byKey(const ValueKey('hero-carousel-prev')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero-carousel-next')), findsOneWidget);

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(image.imageUrl, 'https://example.com/2.jpg');

    await tester.tap(find.bySemanticsLabel('Expand hero header'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Minimize hero header'), findsOneWidget);
    expect(find.text('42 views'), findsOneWidget);

    await _triggerTap(tester, find.byKey(const ValueKey('hero-carousel-next')));

    expect(find.byKey(const ValueKey('hero-carousel-prev')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero-carousel-next')), findsNothing);

    final lastImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(lastImage.imageUrl, 'https://example.com/3.jpg');
  });

  testWidgets('expanded hero header avoids overflow on narrow widths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final event = Event(
      id: 'event-1',
      name: 'Foody - Deckow Community Supper With A Very Long Title',
      description: 'A neighborhood meal with a verified host badge.',
      status: 'upcoming',
      type: 'PUBLIC',
      startTime: DateTime(2026, 3, 20, 19),
      endTime: DateTime(2026, 3, 20, 22),
      createdBy: 'host-1',
      location: const Location(address: 'Main Square'),
      media: [
        Media(id: 'media-1', url: 'https://example.com/1.jpg', type: 'image'),
      ],
      tags: [Tag(id: 'tag-1', name: 'Street Food')],
      verifiers: [
        EventVerifier(
          user: EventUser(id: 'verifier-1', name: 'Riya'),
        ),
      ],
      creator: EventUser(id: 'host-1', name: 'Ash'),
      stats: EventStats(
        reactionCount: 0,
        threadCount: 0,
        participantCount: 0,
        verifierCount: 1,
        mediaCount: 1,
        tagCount: 1,
        viewCount: 42,
        ratingCount: 8,
        ratingAverage: 4.6,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EventDetailScreen(id: event.id, initialEvent: event),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Verified Host'), findsOneWidget);
    expect(find.bySemanticsLabel('Minimize hero header'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows event detail skeletons while remote data is loading', (
    tester,
  ) async {
    final blockingAdapter = _BlockingHttpClientAdapter();
    apiService.dio.httpClientAdapter = blockingAdapter;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EventDetailScreen(id: 'event-1')),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsWidgets);

    blockingAdapter.release();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestOptions.path == '/events/event-1') {
      return _jsonResponse(<String, dynamic>{
        'data': {
          'id': 'event-1',
          'name': 'Street Food Social',
          'description': 'A long dinner table with rotating chefs.',
          'status': 'upcoming',
          'type': 'PUBLIC',
          'timings': {
            'start': '2026-03-20T19:00:00.000Z',
            'end': '2026-03-20T22:00:00.000Z',
          },
          'createdBy': 'host-1',
          'location': {'address': 'Main Square'},
          'media': [
            {
              'id': 'media-1',
              'publicUrl': 'https://example.com/1.jpg',
              'type': 'image',
            },
            {
              'id': 'media-2',
              'publicUrl': 'https://example.com/2.jpg',
              'type': 'image',
            },
            {
              'id': 'media-3',
              'publicUrl': 'https://example.com/3.jpg',
              'type': 'image',
            },
          ],
          'tags': [
            {'id': 'tag-1', 'name': 'Street Food'},
          ],
          'creator': {'id': 'host-1', 'name': 'Ash'},
          'verifiers': [
            {
              'user': {'id': 'verifier-1', 'name': 'Riya'},
            },
          ],
          'stats': {'viewCount': 42, 'ratingCount': 8, 'ratingAverage': 4.6},
        },
      });
    }

    if (requestOptions.path == '/engagement/events/event-1') {
      return _jsonResponse(<String, dynamic>{
        'data': {
          'viewCount': 42,
          'ratingCount': 8,
          'ratingAverage': 4.6,
          'ratingHistogram': const <String, int>{},
          'currentUserRating': null,
          'currentUserReview': null,
        },
      });
    }

    return _jsonResponse(<String, dynamic>{'data': {}}, statusCode: 404);
  }

  ResponseBody _jsonResponse(
    Map<String, dynamic> body, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _BlockingHttpClientAdapter extends _FakeHttpClientAdapter {
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _gate.future;
    return super.fetch(requestOptions, requestStream, cancelFuture);
  }
}

Future<void> _triggerTap(WidgetTester tester, Finder finder) async {
  final gestureDetector = tester.widget<GestureDetector>(finder);
  gestureDetector.onTap?.call();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
