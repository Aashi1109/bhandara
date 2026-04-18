import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foody_mobile/shared/widgets/skeleton.dart';
import 'package:foody_mobile/shared/services/api.dart';
import 'package:foody_mobile/features/saved/screens/saved.dart';

void main() {
  late HttpClientAdapter originalAdapter;
  late _SavedResultsAdapter adapter;

  setUp(() {
    apiService.dio.interceptors.clear();
    originalAdapter = apiService.dio.httpClientAdapter;
    adapter = _SavedResultsAdapter();
    apiService.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiService.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets(
    'pull to refresh reloads saved items and preserves query/filter',
    (tester) async {
      final router = GoRouter(
        initialLocation: SavedScreen.routePath,
        routes: [
          GoRoute(
            path: SavedScreen.routePath,
            builder: (context, state) => const SavedScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await _pumpUntilFound(tester, find.text('Pizza Night'));

      expect(find.text('Pizza Night'), findsOneWidget);
      expect(adapter.savedResultsCalls, 1);

      await tester.enterText(find.byType(TextField), 'Pizza');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.tap(find.text('Events'));
      await _pumpUntilFound(tester, find.text('Pizza Night Reloaded'));

      expect(find.text('Pizza Night Reloaded'), findsOneWidget);
      expect(find.text('Pizza Buddy'), findsNothing);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _pumpUntilFound(tester, find.text('Pizza Night Reloaded'));

      expect(adapter.savedResultsCalls, greaterThanOrEqualTo(2));
      expect(find.text('Pizza Night Reloaded'), findsOneWidget);
      expect(find.text('Pizza Buddy Reloaded'), findsNothing);
      expect(find.widgetWithText(TextField, 'Pizza'), findsOneWidget);
    },
  );

  testWidgets('shows skeletons while saved items are loading', (tester) async {
    final delayedAdapter = _DelayedSavedResultsAdapter();
    apiService.dio.httpClientAdapter = delayedAdapter;

    final router = GoRouter(
      initialLocation: SavedScreen.routePath,
      routes: [
        GoRoute(
          path: SavedScreen.routePath,
          builder: (context, state) => const SavedScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsWidgets);

    delayedAdapter.completeFirstRequest();
    await _pumpUntilFound(tester, find.text('Pizza Night'));
    expect(find.text('Pizza Night'), findsOneWidget);
  });
}

class _SavedResultsAdapter implements HttpClientAdapter {
  int savedResultsCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestOptions.path == '/saves') {
      savedResultsCalls += 1;
      if (savedResultsCalls == 1) {
        return _jsonResponse(
          _savedItemsResponse(
            eventTitle: 'Pizza Night',
            messageTitle: 'Pizza Buddy',
          ),
        );
      }

      return _jsonResponse(
        _savedItemsResponse(
          eventTitle: 'Pizza Night Reloaded',
          messageTitle: 'Pizza Buddy Reloaded',
        ),
      );
    }

    return _jsonResponse(<String, dynamic>{'data': {}}, statusCode: 404);
  }

  Map<String, dynamic> _savedItemsResponse({
    required String eventTitle,
    required String messageTitle,
  }) {
    return <String, dynamic>{
      'data': {
        'items': [
          {
            'entityType': 'event',
            'entity': {
              'id': 'event-1',
              'name': eventTitle,
              'status': 'upcoming',
              'location': {'address': 'Main Square'},
              'timings': {
                'start': '2026-03-20T19:00:00.000Z',
                'end': '2026-03-20T22:00:00.000Z',
              },
              'media': const [],
            },
          },
          {
            'entityType': 'message',
            'entity': {
              'id': 'message-1',
              'threadId': 'thread-1',
              'user': {'name': messageTitle},
              'content': {'text': 'Message body'},
            },
          },
        ],
      },
    };
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

class _DelayedSavedResultsAdapter extends _SavedResultsAdapter {
  final Completer<void> _firstRequest = Completer<void>();

  void completeFirstRequest() {
    if (!_firstRequest.isCompleted) {
      _firstRequest.complete();
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestOptions.path == '/saves' && savedResultsCalls == 0) {
      await _firstRequest.future;
    }

    return super.fetch(requestOptions, requestStream, cancelFuture);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 20,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}
