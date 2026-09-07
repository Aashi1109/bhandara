import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/engagement.dart';
import '../../../shared/providers/user.dart';
import '../services/engagement.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/utils/error.dart';
import '../../../shared/widgets/app_pull_to_refresh.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/header.dart';
import '../widgets/review_editor_sheet.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/snackbar.dart';

class EventRatingsScreen extends ConsumerStatefulWidget {
  const EventRatingsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    this.isOwner = false,
  });

  static const String routePath = '/event/:id/ratings';

  final String eventId;
  final String eventName;
  final bool isOwner;

  @override
  ConsumerState<EventRatingsScreen> createState() => _EventRatingsScreenState();
}

class _EventRatingsScreenState extends ConsumerState<EventRatingsScreen> {
  static const List<int?> _filterOptions = [null, 5, 4, 3, 2, 1];

  EngagementSummary? _summary;
  List<EventReview> _reviews = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int? _selectedRatingFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        engagementService.getEntityEngagement('events', widget.eventId),
        engagementService.getEntityRatings('events', widget.eventId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as EngagementSummary;
        _reviews = results[1] as List<EventReview>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
      if (showLoader) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openEditor() async {
    final summary = _summary;
    if (summary == null || _isSubmitting || widget.isOwner) return;

    final result = await showReviewEditorSheet(
      context,
      initialRating: summary.currentUserRating,
      initialReview: summary.currentUserReview,
    );

    if (result == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      if (result.action == ReviewEditorAction.delete) {
        await engagementService.deleteEntityRating('events', widget.eventId);
      } else {
        await engagementService.rateEntity(
          'events',
          widget.eventId,
          result.rating!,
          review: result.review,
        );
      }
      await _loadData(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  EventReview? _currentUserReview(String? currentUserId) {
    if (currentUserId == null) return null;
    for (final review in _reviews) {
      if (review.userId == currentUserId) {
        return review;
      }
    }
    return null;
  }

  List<EventReview> _publicReviews(String? currentUserId) {
    final reviews = _reviews.where((review) => review.userId != currentUserId);
    if (_selectedRatingFilter == null) {
      return reviews.toList();
    }
    return reviews
        .where((review) => review.value == _selectedRatingFilter)
        .toList();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    return MaterialLocalizations.of(context).formatShortDate(value);
  }

  String _filterLabel(int? value) {
    if (value == null) return 'All ratings';
    return value == 1 ? '1 star' : '$value stars';
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appPalette.muted.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.appPalette.border),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  children: [
                    AppSkeletonLine(width: 56, height: 28),
                    SizedBox(height: 10),
                    AppSkeletonLine(width: 68, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLine(height: 12),
                    SizedBox(height: 12),
                    AppSkeletonLine(width: 180, height: 12),
                    SizedBox(height: 12),
                    AppSkeletonLine(width: 150, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const AppSkeletonLine(width: 92, height: 18),
        const SizedBox(height: 12),
        ...List.generate(3, (_) => _buildReviewSkeleton()),
      ],
    );
  }

  Widget _buildReviewSkeleton() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 44, height: 44, shape: BoxShape.circle),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLine(width: 120, height: 14),
                SizedBox(height: 10),
                AppSkeletonLine(height: 12),
                SizedBox(height: 8),
                AppSkeletonLine(width: 210, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final currentUser = ref.watch(userProfileProvider).value;
    final currentUserReview = _currentUserReview(currentUser?.id);
    final publicReviews = _publicReviews(currentUser?.id);

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          AppHeader(title: 'Ratings & Reviews', subtitle: widget.eventName),
          Expanded(
            child: _isLoading || summary == null
                ? _buildLoadingState()
                : AppPullToRefresh(
                    onRefresh: _loadData,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryCard(context, summary),
                        if (currentUserReview != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Your review',
                            style: context.appTypography.titleMDStrong.copyWith(
                              color: context.appPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _reviewCard(currentUserReview, isCurrentUser: true),
                        ],
                        Divider(height: 32, color: context.appPalette.border),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Reviews',
                                style: context.appTypography.titleMDStrong
                                    .copyWith(color: context.appPalette.primary),
                              ),
                            ),
                            _ratingFilterDropdown(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (publicReviews.isEmpty)
                          _emptyReviewsState()
                        else
                          ...publicReviews.asMap().entries.map(
                            (entry) => Column(
                              children: [
                                _reviewCard(entry.value, isCurrentUser: false),
                                if (entry.key != publicReviews.length - 1)
                                  Divider(
                                    height: 1,
                                    color: context.appPalette.border,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: !widget.isOwner && currentUserReview == null
          ? FloatingActionButton.extended(
              onPressed: _isSubmitting ? null : _openEditor,
              backgroundColor: context.appPalette.primary,
              foregroundColor: context.appPalette.surface,
              label: Text(
                'Add Review',
                style: context.appTypography.labelMD.copyWith(
                  color: context.appPalette.surface,
                ),
              ),
              icon: _isSubmitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appPalette.surface,
                      ),
                    )
                  : const Icon(LucideIcons.pencil),
            )
          : null,
    );
  }

  Widget _summaryCard(BuildContext context, EngagementSummary summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appPalette.muted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 20,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  summary.ratingAverage > 0
                      ? summary.ratingAverage.toStringAsFixed(1)
                      : '0.0',
                  style: context.appTypography.headingXL.copyWith(
                    color: context.appPalette.primary,
                  ),
                ),
                Text(
                  '${summary.ratingCount} ratings',
                  style: context.appTypography.captionMD.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  Padding(
                    padding: EdgeInsets.only(bottom: stars == 1 ? 0 : 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Row(
                            children: [
                              Text(
                                '$stars',
                                style: context.appTypography.labelMD.copyWith(
                                  color: context.appPalette.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: context.appPalette.primary,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: summary.ratingCount == 0
                                  ? 0
                                  : summary.ratingHistogram.valueFor(stars) /
                                        summary.ratingCount,
                              backgroundColor: context.appPalette.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.appPalette.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${summary.ratingHistogram.valueFor(stars)}',
                          style: context.appTypography.labelMD.copyWith(
                            color: context.appPalette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingFilterDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: _selectedRatingFilter,
        icon: Icon(
          LucideIcons.chevronDown,
          size: AppIconSizes.m,
          color: context.appPalette.mutedForeground,
        ),
        borderRadius: BorderRadius.circular(18),
        style: context.appTypography.labelMD.copyWith(color: context.appPalette.primary),
        items: _filterOptions
            .map(
              (value) => DropdownMenuItem<int?>(
                value: value,
                child: Text(_filterLabel(value)),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() => _selectedRatingFilter = value);
        },
      ),
    );
  }

  Widget _emptyReviewsState() {
    final message = _selectedRatingFilter == null
        ? widget.isOwner
              ? 'No reviews yet.'
              : 'No reviews yet. Be the first to add one.'
        : 'No ${_filterLabel(_selectedRatingFilter).toLowerCase()} found yet.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appPalette.muted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Text(
        message,
        style: context.appTypography.bodyMDSemi.copyWith(
          color: context.appPalette.mutedForeground,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _reviewCard(EventReview review, {required bool isCurrentUser}) {
    final name = review.user?.name ?? 'User';
    final avatarUrl = review.user?.avatarUrl ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: name, imageUrl: avatarUrl, size: 52, textSize: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: context.appTypography.titleSM.copyWith(
                        color: context.appPalette.primary,
                      ),
                    ),
                    if (review.updatedAt != null)
                      Text(
                        _formatDate(review.updatedAt),
                        style: context.appTypography.bodySM.copyWith(
                          color: context.appPalette.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 22,
                    color: context.appPalette.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${review.value}',
                    style: context.appTypography.titleSM.copyWith(
                      color: context.appPalette.primary,
                    ),
                  ),
                  if (isCurrentUser && !widget.isOwner) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isSubmitting ? null : _openEditor,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.appPalette.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.appPalette.border),
                          boxShadow: [
                            BoxShadow(
                              color: context.appPalette.primary.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.pencil,
                          size: AppIconSizes.m,
                          color: context.appPalette.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if ((review.review ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              review.review!,
              style: context.appTypography.bodyMD.copyWith(
                color: context.appPalette.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
