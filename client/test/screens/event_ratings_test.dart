import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/models/user.dart';
import 'package:foody_mobile/providers/user.dart';
import 'package:foody_mobile/screens/event_ratings.dart';
import 'package:foody_mobile/services/api.dart';

void main() {
  late HttpClientAdapter originalAdapter;
  late _EventRatingsAdapter adapter;

  setUp(() {
    apiService.dio.interceptors.clear();
    originalAdapter = apiService.dio.httpClientAdapter;
    adapter = _EventRatingsAdapter();
    apiService.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiService.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets('pull to refresh reloads event ratings data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(() => _StaticUserProfile()),
        ],
        child: const MaterialApp(
          home: EventRatingsScreen(
            eventId: 'event-1',
            eventName: 'Street Food Social',
          ),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      condition: () =>
          adapter.engagementCalls == 1 && adapter.ratingsCalls == 1,
    );

    expect(adapter.engagementCalls, 1);
    expect(adapter.ratingsCalls, 1);
    expect(find.text('Guest One'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _pumpUntil(
      tester,
      condition: () =>
          adapter.engagementCalls == 2 && adapter.ratingsCalls == 2,
    );

    expect(adapter.engagementCalls, 2);
    expect(adapter.ratingsCalls, 2);
  });
}

class _StaticUserProfile extends UserProfile {
  @override
  Future<User?> build() async =>
      User(id: 'viewer-1', email: 'viewer@example.com');
}

class _EventRatingsAdapter implements HttpClientAdapter {
  int engagementCalls = 0;
  int ratingsCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestOptions.path == '/engagement/events/event-1') {
      engagementCalls += 1;
      return _jsonResponse(<String, dynamic>{
        'data': {
          'viewCount': 42,
          'ratingCount': 1,
          'ratingAverage': 4.0,
          'ratingHistogram': {'4': 1},
          'currentUserRating': null,
          'currentUserReview': null,
        },
      });
    }

    if (requestOptions.path == '/engagement/events/event-1/ratings') {
      ratingsCalls += 1;
      return _jsonResponse(<String, dynamic>{
        'data': [
          {
            'id': 'review-1',
            'userId': 'guest-1',
            'value': 4,
            'review': 'Great night.',
            'createdAt': '2026-03-20T20:00:00.000Z',
            'user': {'id': 'guest-1', 'name': 'Guest One'},
          },
        ],
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

Future<void> _pumpUntil(
  WidgetTester tester, {
  required bool Function() condition,
  int maxAttempts = 20,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) {
      return;
    }
  }
}
