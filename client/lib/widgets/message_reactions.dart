import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/socket_events.dart';
import '../models/chat.dart';
import '../services/socket.dart';
import '../theme/theme.dart';
import 'avatar.dart';

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

  static List<MessageReaction> filterByEmoji(
    List<MessageReaction> reactions, {
    String? emoji,
  }) {
    if (emoji == null || emoji.isEmpty) {
      return List<MessageReaction>.from(reactions);
    }

    return reactions.where((reaction) => reaction.emoji == emoji).toList();
  }

  static String displayName(
    MessageReaction reaction, {
    required String? currentUserId,
  }) {
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        reaction.userId == currentUserId) {
      return 'You';
    }

    final name = reaction.user?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Unknown user';
  }

  static List<MessageReaction> applySocketEvent({
    required List<MessageReaction> reactions,
    required String eventName,
    required MessageReaction reaction,
  }) {
    final next = List<MessageReaction>.from(reactions);
    switch (eventName) {
      case SocketEvents.reactionCreate:
      case SocketEvents.reactionUpdate:
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
      case SocketEvents.reactionDelete:
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
          ? SocketEvents.reactionDelete
          : existing != null
          ? SocketEvents.reactionUpdate
          : SocketEvents.reactionCreate,
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
    final typography = context.appTypography;

    final selectedEmoji = MessageReactionUtils.currentUserReactionEmoji(
      reactions,
      currentUserId,
    );

    final summaryKey = summaries
        .map((summary) => '${summary.emoji}:${summary.count}')
        .join('|');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: Wrap(
        key: ValueKey(summaryKey),
        spacing: 8,
        runSpacing: 8,
        children: summaries.map((summary) {
          final isSelected = summary.emoji == selectedEmoji;
          return GestureDetector(
            onTap: () => showMessageReactionDetailsSheet(
              context: context,
              reactions: reactions,
              currentUserId: currentUserId,
              initialEmoji: summary.emoji,
            ),
            onLongPress: isEnabled
                ? () async {
                    await HapticFeedback.selectionClick();
                    onTap(summary.emoji);
                  }
                : null,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(
                'reaction_${summary.emoji}_${summary.count}_$isSelected',
              ),
              tween: Tween<double>(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                    Text(summary.emoji, style: typography.bodyMD),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        '${summary.count}',
                        key: ValueKey('${summary.emoji}_${summary.count}'),
                        style: isSelected
                            ? typography.captionSMStrong.copyWith(
                                color: AppColors.primary,
                              )
                            : typography.captionSM.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
    final typography = context.appTypography;
    return Material(
      color: AppColors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
              child: TweenAnimationBuilder<double>(
                key: ValueKey('quick_${emoji}_$isSelected'),
                tween: Tween<double>(begin: 0.88, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
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
                  child: Text(emoji, style: typography.titleLG),
                ),
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
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.9, end: 1),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.scale(scale: value, child: child),
                  );
                },
                child: MessageReactionQuickBar(
                  currentUserReactionEmoji: currentUserReactionEmoji,
                  onSelected: (emoji) async {
                    await HapticFeedback.selectionClick();
                    dismiss();
                    await onSelected(emoji);
                  },
                ),
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

Future<void> showMessageReactionDetailsSheet({
  required BuildContext context,
  required List<MessageReaction> reactions,
  required String? currentUserId,
  String? initialEmoji,
}) async {
  final summaries = MessageReactionUtils.summarize(reactions);
  if (summaries.isEmpty) {
    return;
  }

  String? selectedEmoji = initialEmoji;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final typography = context.appTypography;
          final filtered =
              MessageReactionUtils.filterByEmoji(
                reactions,
                emoji: selectedEmoji,
              )..sort((a, b) {
                final aIsCurrent = a.userId == currentUserId;
                final bIsCurrent = b.userId == currentUserId;
                if (aIsCurrent != bIsCurrent) {
                  return aIsCurrent ? -1 : 1;
                }

                final aName = MessageReactionUtils.displayName(
                  a,
                  currentUserId: currentUserId,
                );
                final bName = MessageReactionUtils.displayName(
                  b,
                  currentUserId: currentUserId,
                );
                return aName.toLowerCase().compareTo(bName.toLowerCase());
              });

          return SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.72,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Reactions',
                            style: typography.titleMDStrong.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _ReactionFilterChip(
                            label: 'All',
                            count: reactions.length,
                            isSelected: selectedEmoji == null,
                            onTap: () =>
                                setModalState(() => selectedEmoji = null),
                          ),
                          ...summaries.map((summary) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _ReactionFilterChip(
                                label: summary.emoji,
                                count: summary.count,
                                isSelected: selectedEmoji == summary.emoji,
                                onTap: () => setModalState(
                                  () => selectedEmoji = summary.emoji,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final reaction = filtered[index];
                          final displayName = MessageReactionUtils.displayName(
                            reaction,
                            currentUserId: currentUserId,
                          );

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Avatar(
                                  name: reaction.user?.name ?? displayName,
                                  imageUrl: reaction.user?.avatarUrl,
                                  size: 36,
                                  textSize: 14,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: typography.labelMD.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    reaction.emoji,
                                    style: typography.titleSM,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ReactionFilterChip extends StatelessWidget {
  const _ReactionFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            Text(
              label,
              style: typography.captionMD.copyWith(
                color: isSelected ? AppColors.primary : AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: isSelected
                  ? typography.bodySMExtraBold.copyWith(
                      color: AppColors.primary,
                    )
                  : typography.bodySMStrong.copyWith(
                      color: AppColors.mutedForeground,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
