import './event.dart';

class EngagementSummary {
  EngagementSummary({
    required this.viewCount,
    required this.ratingCount,
    required this.ratingAverage,
    required this.ratingHistogram,
    required this.currentUserRating,
    required this.currentUserReview,
    this.currentUserReviewedAt,
  });

  factory EngagementSummary.fromJson(Map<String, dynamic> json) {
    return EngagementSummary(
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
      ratingHistogram: RatingHistogram.fromJson(
        json['ratingHistogram'] as Map<String, dynamic>? ?? const {},
      ),
      currentUserRating: (json['currentUserRating'] as num?)?.toInt(),
      currentUserReview: json['currentUserReview'] as String?,
      currentUserReviewedAt: json['currentUserReviewedAt'] != null
          ? DateTime.tryParse(json['currentUserReviewedAt'] as String)
          : null,
    );
  }

  final int viewCount;
  final int ratingCount;
  final double ratingAverage;
  final RatingHistogram ratingHistogram;
  final int? currentUserRating;
  final String? currentUserReview;
  final DateTime? currentUserReviewedAt;
}

class RatingHistogram {
  const RatingHistogram({
    required this.one,
    required this.two,
    required this.three,
    required this.four,
    required this.five,
  });

  factory RatingHistogram.fromJson(Map<String, dynamic> json) {
    return RatingHistogram(
      one: (json['1'] as num?)?.toInt() ?? 0,
      two: (json['2'] as num?)?.toInt() ?? 0,
      three: (json['3'] as num?)?.toInt() ?? 0,
      four: (json['4'] as num?)?.toInt() ?? 0,
      five: (json['5'] as num?)?.toInt() ?? 0,
    );
  }

  int valueFor(int stars) {
    switch (stars) {
      case 1:
        return one;
      case 2:
        return two;
      case 3:
        return three;
      case 4:
        return four;
      case 5:
      default:
        return five;
    }
  }

  final int one;
  final int two;
  final int three;
  final int four;
  final int five;
}

class EventReview {
  EventReview({
    required this.id,
    required this.userId,
    required this.value,
    this.review,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  factory EventReview.fromJson(Map<String, dynamic> json) {
    return EventReview(
      id: json['id'] as String,
      userId: json['userId'] as String,
      value: (json['value'] as num?)?.toInt() ?? 0,
      review: json['review'] as String?,
      user: json['user'] is Map<String, dynamic>
          ? EventUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  final String id;
  final String userId;
  final int value;
  final String? review;
  final EventUser? user;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
