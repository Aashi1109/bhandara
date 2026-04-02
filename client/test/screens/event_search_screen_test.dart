import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foody_mobile/models/event.dart';
import 'package:foody_mobile/models/search_event_item.dart';
import 'package:foody_mobile/models/user.dart';
import 'package:foody_mobile/providers/user.dart';
import 'package:foody_mobile/screens/explore/explore_screen.dart';
import 'package:foody_mobile/screens/search.dart';
import 'package:foody_mobile/services/api.dart';
import 'package:foody_mobile/services/search_history.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;
  late _EventSearchAdapter adapter;
  late _FakeSearchHistoryService historyService;

  final testUser = User(
    id: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
    address: UserAddress(
      label: 'Base',
      latitude: 21.1458,
      longitude: 79.0882,
    ),
  );

  setUp(() {
    apiService.dio.interceptors.clear();
    originalAdapter = apiService.dio.httpClientAdapter;
    adapter = _EventSearchAdapter();
    apiService.dio.httpClientAdapter = adapter;
    historyService = _FakeSearchHistoryService(
      history: [
        SearchEventItem(
          id: 'history-1',
          name: 'History Dinner',
          location: Location(
            address: 'History Square',
            latitude: 21.1460,
            longitude: 79.0884,
          ),
          startTime: DateTime.parse('2026-03-29T18:00:00.000Z'),
          endTime: DateTime.parse('2026-03-29T20:00:00.000Z'),
          createdAt: DateTime.parse('2026-03-27T08:00:00.000Z'),
        ),
      ],
    );
  });

  tearDown(() {
    apiService.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets('shows local history above recently added events on landing', (
    tester,
  ) async {
    await _pumpSearchScreen(
      tester,
      historyService: historyService,
      user: testUser,
    );

    await _pumpUntilFound(tester, find.text('History Dinner'));

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('History Dinner'), findsOneWidget);
    expect(find.text('Fresh Feast'), findsOneWidget);
    expect(adapter.eventsCalls, 1);
  });

  testWidgets('searches events and records selected history item', (
    tester,
  ) async {
    await _pumpSearchScreen(
      tester,
      historyService: historyService,
      user: testUser,
    );

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 350));
    await _pumpUntilFound(tester, find.text('Pizza Pop-up'));

    expect(adapter.searchCalls, 1);

    await tester.tap(find.text('Pizza Pop-up'));
    await tester.pumpAndSettle();

    expect(historyService.lastSelected?.id, 'search-1');
    expect(find.text('detail:search-1'), findsOneWidget);
  });

  testWidgets('back button falls back to explore when there is no stack entry', (
    tester,
  ) async {
    await _pumpSearchScreen(
      tester,
      historyService: historyService,
      user: testUser,
    );

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    expect(find.text('explore-screen'), findsOneWidget);
  });
}

Future<void> _pumpSearchScreen(
  WidgetTester tester, {
  required _FakeSearchHistoryService historyService,
  required User user,
}) async {
  final router = GoRouter(
    initialLocation: SearchScreen.routePath,
    routes: [
      GoRoute(
        path: ExploreScreen.routePath,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('explore-screen')),
        ),
      ),
      GoRoute(
        path: SearchScreen.routePath,
        builder: (context, state) => SearchScreen(historyService: historyService),
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) => Scaffold(
          body: Center(child: Text('detail:${state.pathParameters['id']}')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(() => _TestUserProfile(user)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

class _EventSearchAdapter implements HttpClientAdapter {
  int eventsCalls = 0;
  int searchCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestOptions.path == '/events') {
      eventsCalls += 1;
      return _jsonResponse({
        'data': {
          'items': [
            {
              'id': 'recent-1',
              'name': 'Fresh Feast',
              'status': 'upcoming',
              'type': 'organized',
              'createdBy': 'user-2',
              'createdAt': '2026-03-27T10:00:00.000Z',
              'updatedAt': '2026-03-27T10:00:00.000Z',
              'location': {
                'address': 'Food Street',
                'latitude': 21.1459,
                'longitude': 79.0891,
              },
              'timings': {
                'start': '2026-03-30T18:00:00.000Z',
                'end': '2026-03-30T20:00:00.000Z',
              },
              'media': const [],
            },
          ],
          'pagination': {
            'hasNext': false,
            'limit': 10,
            'next': null,
            'total': 1,
          },
        },
      });
    }

    if (requestOptions.path == '/search') {
      searchCalls += 1;
      return _jsonResponse({
        'data': {
          'items': [
            {
              'id': 'search-1',
              'type': 'event',
              'title': 'Pizza Pop-up',
              'description': 'Late-night slices.',
              'imageUrl': null,
              'metadata': {
                'status': 'ongoing',
                'type': 'custom',
                'createdAt': '2026-03-27T09:00:00.000Z',
                'location': {
                  'address': 'Pizza Lane',
                  'latitude': 21.1457,
                  'longitude': 79.0888,
                },
                'timings': {
                  'start': '2026-03-27T17:00:00.000Z',
                  'end': '2026-03-27T23:00:00.000Z',
                },
              },
            },
          ],
          'pagination': {
            'hasNext': false,
            'limit': 20,
            'next': null,
            'total': 1,
          },
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

class _FakeSearchHistoryService extends SearchHistoryService {
  _FakeSearchHistoryService({required this.history});

  List<SearchEventItem> history;
  SearchEventItem? lastSelected;

  @override
  Future<List<SearchEventItem>> getHistory() async => history;

  @override
  Future<void> addSelection(SearchEventItem item) async {
    lastSelected = item;
    history = [item, ...history.where((entry) => entry.id != item.id)];
  }
}

class _TestUserProfile extends UserProfile {
  _TestUserProfile(this.user);

  final User user;

  @override
  FutureOr<User?> build() async => user;
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
