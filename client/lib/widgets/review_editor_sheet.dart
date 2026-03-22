import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'button.dart';
import 'textarea.dart';

enum ReviewEditorAction { submit, delete }

class ReviewEditorResult {
  const ReviewEditorResult.submit({required this.rating, required this.review})
    : action = ReviewEditorAction.submit;

  const ReviewEditorResult.delete()
    : action = ReviewEditorAction.delete,
      rating = null,
      review = null;

  final ReviewEditorAction action;
  final int? rating;
  final String? review;
}

Future<ReviewEditorResult?> showReviewEditorSheet(
  BuildContext context, {
  int? initialRating,
  String? initialReview,
}) {
  return showModalBottomSheet<ReviewEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewEditorSheet(
      initialRating: initialRating,
      initialReview: initialReview,
    ),
  );
}

class _ReviewEditorSheet extends StatefulWidget {
  const _ReviewEditorSheet({
    required this.initialRating,
    required this.initialReview,
  });

  final int? initialRating;
  final String? initialReview;

  @override
  State<_ReviewEditorSheet> createState() => _ReviewEditorSheetState();
}

class _ReviewEditorSheetState extends State<_ReviewEditorSheet> {
  late final TextEditingController _controller;
  int? _rating;
  String? _error;

  bool get _isEditing => widget.initialRating != null;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _controller = TextEditingController(text: widget.initialReview ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == null) {
      setState(() => _error = 'Select a star rating to continue.');
      return;
    }

    Navigator.of(context).pop(
      ReviewEditorResult.submit(
        rating: _rating,
        review: _controller.text.trim().isEmpty
            ? null
            : _controller.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(28),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Edit Review' : 'Add Review',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your rating and an optional note for other attendees.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              spacing: 8,
              children: [
                for (var index = 1; index <= 5; index++)
                  GestureDetector(
                    onTap: () => setState(() {
                      _rating = index;
                      _error = null;
                    }),
                    child: Icon(
                      index <= (_rating ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: index <= (_rating ?? 0)
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            AppTextArea(
              placeholder: 'Write an optional review...',
              controller: _controller,
              minLines: 5,
              maxLines: 5,
              borderRadius: 20,
              backgroundColor: AppColors.muted.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 20),
            Row(
              spacing: 12,
              children: [
                if (_isEditing) ...[
                  Expanded(
                    child: AppButton(
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.lg,
                      label: 'Remove',
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const ReviewEditorResult.delete()),
                    ),
                  ),
                ],
                Expanded(
                  child: AppButton(
                    size: AppButtonSize.lg,
                    label: _isEditing ? 'Update Review' : 'Add Review',
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
