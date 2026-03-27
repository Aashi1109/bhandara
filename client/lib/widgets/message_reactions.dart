import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/socket_events.dart';
import '../models/chat.dart';
import '../services/socket.dart';
import '../theme/theme.dart';

class MessageReactionSummary {
  const MessageReactionSummary({required this.emoji, required this.count});

  final String emoji;
  final int count;
}

class MessageReactionMutation {
  const MessageReactionMutation({
    required this.previous,
    required this.optimistic,
    required this.eventName,
  });

  final List<MessageReaction> previous;
  final List<MessageReaction> optimistic;
  final String eventName;
}

class MessageReactionUtils {
  static const List<String> quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  static String? currentUserReactionEmoji(
    List<MessageReaction> reactions,
    String? userId,
  ) {
    if (userId == null || userId.isEmpty) {
      return null;
    }

    for (final reaction in reactions) {
      if (reaction.userId == userId) {
        return reaction.emoji;
      }
    }

    return null;
  }

  static List<MessageReactionSummary> summarize(
    List<MessageReaction> reactions,
  ) {
    final grouped = <String, int>{};
    for (final reaction in reactions) {
      if (reaction.emoji.isEmpty) {
        continue;
      }
      grouped.update(reaction.emoji, (value) => value + 1, ifAbsent: () => 1);
    }

    final orderedEmojis = <String>[
      ...quickEmojis,
      ...grouped.keys.where((emoji) => !quickEmojis.contains(emoji)),
    ];

    return orderedEmojis
        .where((emoji) => (grouped[emoji] ?? 0) > 0)
        .map(
          (emoji) =>
              MessageReactionSummary(emoji: emoji, count: grouped[emoji] ?? 0),
        )
        .toList();
  }

  static List<MessageReaction> applySocketEvent({
    required List<MessageReaction> reactions,
    required String eventName,
    required MessageReaction reaction,
  }) {
    final next = List<MessageReaction>.from(reactions);
    switch (eventName) {
      case SocketEvents.reactionCreated:
      case SocketEvents.reactionUpdated:
        final sameIdIndex = next.indexWhere((item) => item.id == reaction.id);
        final sameUserIndex = next.indexWhere(
          (item) => item.userId == reaction.userId,
        );
        if (sameIdIndex != -1) {
          next[sameIdIndex] = reaction;
        } else if (sameUserIndex != -1) {
          next[sameUserIndex] = reaction;
        } else {
          next.add(reaction);
        }
        return next;
      case SocketEvents.reactionDeleted:
        next.removeWhere((item) => item.id == reaction.id);
        return next;
      default:
        return next;
    }
  }

  static MessageReactionMutation createMutation({
    required List<MessageReaction> reactions,
    required String emoji,
    required String contentId,
    required String contentPath,
    required String? currentUserId,
  }) {
    MessageReaction? existing;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      for (final reaction in reactions) {
        if (reaction.userId == currentUserId) {
          existing = reaction;
          break;
        }
      }
    }

    final isRemoving = existing != null && existing.emoji == emoji;
    final optimisticReaction = MessageReaction(
      id: existing?.id ?? 'local_${DateTime.now().microsecondsSinceEpoch}',
      contentId: '$contentPath/$contentId',
      emoji: emoji,
      userId: currentUserId ?? '',
      user: existing?.user,
    );

    final optimistic = List<MessageReaction>.from(reactions);
    if (isRemoving) {
      optimistic.removeWhere((item) => item.userId == existing?.userId);
    } else if (existing != null) {
      final sameUserIndex = optimistic.indexWhere(
        (item) => item.userId == existing!.userId,
      );
      if (sameUserIndex != -1) {
        optimistic[sameUserIndex] = optimisticReaction;
      }
    } else {
      optimistic.add(optimisticReaction);
    }

    return MessageReactionMutation(
      previous: List<MessageReaction>.from(reactions),
      optimistic: optimistic,
      eventName: isRemoving
          ? SocketEvents.reactionDeleted
          : existing != null
          ? SocketEvents.reactionUpdated
          : SocketEvents.reactionCreated,
    );
  }

  static Future<void> emitReaction({
    required String eventName,
    required String contentId,
    required String contentPath,
    required String emoji,
  }) {
    return socketService.emit(eventName, {
      'contentId': contentId,
      'contentPath': contentPath,
      'reaction': emoji,
    });
  }
}

class MessageReactionSummaryRow extends StatelessWidget {
  const MessageReactionSummaryRow({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onTap,
    this.isEnabled = true,
  });

  final List<MessageReaction> reactions;
  final String? currentUserId;
  final ValueChanged<String> onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final summaries = MessageReactionUtils.summarize(reactions);
    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedEmoji = MessageReactionUtils.currentUserReactionEmoji(
      reactions,
      currentUserId,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: summaries.map((summary) {
        final isSelected = summary.emoji == selectedEmoji;
        return GestureDetector(
          onTap: isEnabled ? () => onTap(summary.emoji) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.muted,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(summary.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '${summary.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MessageReactionQuickBar extends StatelessWidget {
  const MessageReactionQuickBar({
    super.key,
    required this.onSelected,
    this.currentUserReactionEmoji,
  });

  final ValueChanged<String> onSelected;
  final String? currentUserReactionEmoji;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: MessageReactionUtils.quickEmojis.map((emoji) {
            final isSelected = emoji == currentUserReactionEmoji;
            return GestureDetector(
              onTap: () => onSelected(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

Future<void> showMessageReactionOverlay({
  required BuildContext context,
  required BuildContext targetContext,
  required FutureOr<void> Function(String emoji) onSelected,
  required String? currentUserReactionEmoji,
  List<ScrollController> dismissOnScrollControllers = const [],
}) async {
  final overlay = Overlay.of(context, rootOverlay: false);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  final targetBox = targetContext.findRenderObject() as RenderBox?;
  if (overlayBox == null || targetBox == null) {
    return;
  }

  final targetTopLeft = targetBox.localToGlobal(
    Offset.zero,
    ancestor: overlayBox,
  );
  final targetRect = targetTopLeft & targetBox.size;
  final overlaySize = overlayBox.size;
  final barWidth = math.min(320.0, overlaySize.width - 32);
  const barHeight = 64.0;
  const horizontalPadding = 16.0;
  const verticalGap = 12.0;

  final left = math.max(
    horizontalPadding,
    math.min(
      targetRect.center.dx - (barWidth / 2),
      overlaySize.width - barWidth - horizontalPadding,
    ),
  );
  final preferredTop = targetRect.top - barHeight - verticalGap;
  final top = preferredTop >= horizontalPadding
      ? preferredTop
      : math.min(
          targetRect.bottom + verticalGap,
          overlaySize.height - barHeight - horizontalPadding,
        );

  final completer = Completer<void>();
  OverlayEntry? entry;
  final listeners = <VoidCallback>[];

  void dismiss() {
    if (entry == null) {
      return;
    }
    for (var i = 0; i < dismissOnScrollControllers.length; i++) {
      dismissOnScrollControllers[i].removeListener(listeners[i]);
    }
    entry!.remove();
    entry = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  for (final controller in dismissOnScrollControllers) {
    void listener() {
      dismiss();
    }

    listeners.add(listener);
    controller.addListener(listener);
  }

  await HapticFeedback.mediumImpact();

  entry = OverlayEntry(
    builder: (_) {
      return Positioned.fill(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismiss,
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: left,
              top: top,
              child: MessageReactionQuickBar(
                currentUserReactionEmoji: currentUserReactionEmoji,
                onSelected: (emoji) async {
                  await HapticFeedback.selectionClick();
                  dismiss();
                  await onSelected(emoji);
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  if (entry != null) overlay.insert(entry!);
  return completer.future;
}
