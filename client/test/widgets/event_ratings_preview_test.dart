import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/models/engagement.dart';
import 'package:foody_mobile/features/events/models/event.dart';
import 'package:foody_mobile/features/events/widgets/event_ratings_preview.dart';

void main() {
  testWidgets('shows rating summary, personal review, and community preview', (
    tester,
  ) async {
    var openedRatings = false;
    var editedReview = false;
    final summary = EngagementSummary(
      viewCount: 42,
      ratingCount: 18,
      ratingAverage: 4.6,
      ratingHistogram: const RatingHistogram(
        one: 0,
        two: 0,
        three: 1,
        four: 4,
        five: 13,
      ),
      currentUserRating: 5,
      currentUserReview: 'Warm hosting and thoughtful pacing.',
      currentUserReviewedAt: DateTime(2026, 5, 3),
    );
    final recentReview = EventReview(
      id: 'review-2',
      userId: 'guest-2',
      value: 5,
      review: 'Beautiful setting and genuinely welcoming.',
      user: EventUser(id: 'guest-2', name: 'Jon Lee'),
      createdAt: DateTime(2026, 5, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: EventRatingsPreview(
                summary: summary,
                recentReview: recentReview,
                isOwner: false,
                isSubmitting: false,
                onOpenRatings: () => openedRatings = true,
                onEditReview: () => editedReview = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('94% RECOMMEND'), findsOneWidget);
    expect(find.textContaining('Warm hosting'), findsOneWidget);
    expect(find.text('Jon Lee'), findsOneWidget);
    expect(find.textContaining('Beautiful setting'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Read all reviews'));
    expect(openedRatings, isTrue);

    await tester.tap(find.byKey(const ValueKey('edit-event-review')));
    expect(editedReview, isTrue);
  });

  testWidgets('offers the first review when there are no ratings', (
    tester,
  ) async {
    var editRequested = false;
    final summary = EngagementSummary(
      viewCount: 0,
      ratingCount: 0,
      ratingAverage: 0,
      ratingHistogram: const RatingHistogram(
        one: 0,
        two: 0,
        three: 0,
        four: 0,
        five: 0,
      ),
      currentUserRating: null,
      currentUserReview: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventRatingsPreview(
            summary: summary,
            isOwner: false,
            isSubmitting: false,
            onOpenRatings: () {},
            onEditReview: () => editRequested = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Be the first to review'));
    expect(editRequested, isTrue);
  });
}
