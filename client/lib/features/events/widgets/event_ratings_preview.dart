import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/avatar.dart';
import '../models/engagement.dart';

class EventRatingsPreview extends StatelessWidget {
  const EventRatingsPreview({
    super.key,
    required this.summary,
    required this.isOwner,
    required this.isSubmitting,
    required this.onOpenRatings,
    required this.onEditReview,
    this.recentReview,
  });

  final EngagementSummary summary;
  final EventReview? recentReview;
  final bool isOwner;
  final bool isSubmitting;
  final VoidCallback onOpenRatings;
  final VoidCallback onEditReview;

  bool get _hasRatings => summary.ratingCount > 0;

  int get _recommendationPercent {
    if (!_hasRatings) return 0;
    final recommended =
        summary.ratingHistogram.five + summary.ratingHistogram.four;
    return ((recommended / summary.ratingCount) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRatings) return _emptyState(context);

    return Column(
      key: const ValueKey('event-ratings-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 16),
        _summary(context),
        if (summary.currentUserRating != null) ...[
          const SizedBox(height: 16),
          _currentUserReview(context),
        ],
        if (recentReview != null) ...[
          const SizedBox(height: 16),
          _communityReview(context, recentReview!),
        ],
        const SizedBox(height: 16),
        _allReviewsButton(context),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Ratings & Reviews',
            style: context.appTypography.titleMD,
          ),
        ),
        GestureDetector(
          onTap: onOpenRatings,
          child: Text(
            'See all ${summary.ratingCount}',
            style: context.appTypography.bodySMStrong.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final rows = <({String label, int count})>[
      (label: '5', count: summary.ratingHistogram.five),
      (label: '4', count: summary.ratingHistogram.four),
      (
        label: '3–1',
        count:
            summary.ratingHistogram.three +
            summary.ratingHistogram.two +
            summary.ratingHistogram.one,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                summary.ratingAverage.toStringAsFixed(1),
                style: context.appTypography.headingXL,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stars(summary.ratingAverage, size: 16),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.ratingCount} guest ratings',
                      style: context.appTypography.captionSM.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (_recommendationPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_recommendationPercent% RECOMMEND',
                    style: context.appTypography.overlineEmphasis.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((row) => _distributionRow(context, row.label, row.count)),
        ],
      ),
    );
  }

  Widget _distributionRow(BuildContext context, String label, int count) {
    final progress = summary.ratingCount == 0
        ? 0.0
        : count / summary.ratingCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(label, style: context.appTypography.captionSMStrong),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: context.appTypography.captionSM.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentUserReview(BuildContext context) {
    final review = summary.currentUserReview?.trim();
    final reviewedAt = summary.currentUserReviewedAt;
    final date = reviewedAt == null
        ? null
        : MaterialLocalizations.of(context).formatShortDate(reviewedAt);

    return Container(
      key: const ValueKey('event-current-user-review'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date == null ? 'YOUR REVIEW' : 'YOUR REVIEW · $date',
                  style: context.appTypography.overlineEmphasis,
                ),
              ),
              _stars((summary.currentUserRating ?? 0).toDouble(), size: 15),
              if (!isOwner) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  key: const ValueKey('edit-event-review'),
                  onTap: isSubmitting ? null : onEditReview,
                  child: Icon(
                    LucideIcons.pencil,
                    size: AppIconSizes.m,
                    color: isSubmitting
                        ? AppColors.mutedForeground
                        : AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
          if (review != null && review.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '“$review”',
              style: context.appTypography.bodyMD.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _communityReview(BuildContext context, EventReview review) {
    final reviewText = review.review?.trim() ?? '';
    final date = review.createdAt == null
        ? null
        : MaterialLocalizations.of(context).formatShortDate(review.createdAt!);

    return Container(
      key: const ValueKey('event-community-review-preview'),
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(
                name: review.user?.name,
                imageUrl: review.user?.avatarUrl,
                size: 36,
                textSize: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.user?.name ?? 'Guest',
                      style: context.appTypography.bodySMStrong,
                    ),
                    Text(
                      date == null
                          ? 'Attended this event'
                          : '$date · Attended this event',
                      style: context.appTypography.captionSM.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _stars(review.value.toDouble(), size: 13),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '“$reviewText”',
              style: context.appTypography.bodySM.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _allReviewsButton(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpenRatings,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 42,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Read all reviews',
                style: context.appTypography.bodySMStrong.copyWith(
                  color: AppColors.surface,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.arrowRight,
                size: AppIconSizes.m,
                color: AppColors.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('No review yet', style: context.appTypography.titleMD),
        ),
        GestureDetector(
          onTap: isOwner || isSubmitting ? null : onEditReview,
          child: Text(
            isOwner ? 'No reviews yet' : 'Be the first to review',
            style: context.appTypography.captionMD.copyWith(
              color: isOwner || isSubmitting
                  ? AppColors.mutedForeground
                  : AppColors.primary,
              decoration: isOwner ? null : TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stars(double rating, {required double size}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final difference = rating - index;
        final icon = difference >= 1
            ? Icons.star_rounded
            : difference >= 0.5
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;
        return Icon(icon, size: size, color: AppColors.accent);
      }),
    );
  }
}
