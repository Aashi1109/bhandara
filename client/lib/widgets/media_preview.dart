import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/chat.dart';
import '../services/socket.dart';
import '../theme/theme.dart';
import '../utils/file_size.dart';
import 'message_reactions.dart';

class MediaItem {
  MediaItem({
    required this.id,
    required this.url,
    required this.thumbnail,
    required this.type,
    required this.name,
    this.sizeBytes,
  });

  final String id;
  final String url;
  final String thumbnail;
  final String type; // 'image' or 'video'
  final String name;
  final int? sizeBytes;
}

class AppMediaPreview extends StatefulWidget {
  const AppMediaPreview({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onClose,
    this.reactionContentId,
    this.reactionContentPath,
    this.initialReactions = const [],
    this.currentUserId,
    this.loadReactions,
  });

  final List<MediaItem> items;
  final int initialIndex;
  final VoidCallback? onClose;
  final String? reactionContentId;
  final String? reactionContentPath;
  final List<MessageReaction> initialReactions;
  final String? currentUserId;
  final Future<List<MessageReaction>> Function()? loadReactions;

  @override
  State<AppMediaPreview> createState() => _AppMediaPreviewState();
}

class _AppMediaPreviewState extends State<AppMediaPreview> {
  late PageController _pageController;
  late int _currentIndex;
  late List<MessageReaction> _reactions;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  StreamSubscription<SocketConnectionStatus>? _socketStatusSubscription;
  bool _isSubmittingReaction = false;
  bool _isSocketReady = false;
  bool _isRefreshingReactions = false;

  bool get _hasMultipleItems => widget.items.length > 1;
  bool get _hasReactionContext =>
      (widget.reactionContentId?.isNotEmpty ?? false) &&
      (widget.reactionContentPath?.isNotEmpty ?? false);
  bool get _showReactionRow => _hasReactionContext;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _reactions = List<MessageReaction>.from(widget.initialReactions);
    _attachReactionStream();
    unawaited(_refreshReactions());
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socketStatusSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _attachReactionStream() {
    if (!_hasReactionContext) {
      return;
    }

    _isSocketReady = socketService.isConnected;
    _socketStatusSubscription?.cancel();
    _socketStatusSubscription = socketService.connectionStatus.listen((status) {
      if (!mounted) return;
      setState(() {
        _isSocketReady = status == SocketConnectionStatus.connected;
      });
    });

    _socketSubscription = socketService.messages.listen((event) {
      if (!mounted) return;
      final eventName = event['event'] as String?;
      final payload = event['data'];
      if (payload is! Map<String, dynamic>) return;
      if (payload['id'] != widget.reactionContentId ||
          payload['contentPath'] != widget.reactionContentPath) {
        return;
      }

      final rawReaction = payload['reaction'];
      if (rawReaction is! Map<String, dynamic>) return;
      final reaction = MessageReaction.fromJson(rawReaction);

      setState(() {
        _reactions = MessageReactionUtils.applySocketEvent(
          reactions: _reactions,
          eventName: eventName ?? '',
          reaction: reaction,
        );
      });
    });
  }

  Future<void> _refreshReactions() async {
    final loader = widget.loadReactions;
    if (!_hasReactionContext || loader == null || _isRefreshingReactions) {
      return;
    }

    _isRefreshingReactions = true;
    try {
      final reactions = await loader();
      if (!mounted) return;
      setState(() {
        _reactions = List<MessageReaction>.from(reactions);
      });
    } catch (_) {
      // Keep current optimistic/local state if refresh fails.
    } finally {
      _isRefreshingReactions = false;
    }
  }

  Future<void> _openEmojiPicker() async {
    if (!_hasReactionContext) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                Navigator.of(context).pop();
                _handleReactionTap(emoji.emoji);
              },
              config: const Config(
                height: 320,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: AppColors.surface,
                  columns: 8,
                ),
                categoryViewConfig: CategoryViewConfig(
                  initCategory: Category.SMILEYS,
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.primary,
                  iconColorSelected: AppColors.primary,
                  iconColor: AppColors.mutedForeground,
                  dividerColor: AppColors.border,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: AppColors.surface,
                  buttonIconColor: AppColors.mutedForeground,
                  inputTextStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  hintTextStyle: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                bottomActionBarConfig: BottomActionBarConfig(enabled: false),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleReactionTap(String emoji) async {
    if (!_hasReactionContext || _isSubmittingReaction) {
      return;
    }

    if (!socketService.isConnected) {
      if (mounted) {
        setState(() {
          _isSocketReady = false;
        });
      }
      return;
    }

    final contentId = widget.reactionContentId!;
    final contentPath = widget.reactionContentPath!;
    final mutation = MessageReactionUtils.createMutation(
      reactions: _reactions,
      emoji: emoji,
      contentId: contentId,
      contentPath: contentPath,
      currentUserId: widget.currentUserId,
    );

    setState(() {
      _isSubmittingReaction = true;
      _reactions = mutation.optimistic;
    });

    try {
      await MessageReactionUtils.emitReaction(
        eventName: mutation.eventName,
        contentId: contentId,
        contentPath: contentPath,
        emoji: emoji,
      );
      unawaited(_refreshReactions());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reactions = mutation.previous;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReaction = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      size: AppIconSizes.defaultSize,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      widget.items[_currentIndex].name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} OF ${widget.items.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.download,
                    size: AppIconSizes.defaultSize,
                  ),
                ),
              ],
            ),
          ),

          // Main View
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: item.type == 'image'
                              ? Image.network(item.url, fit: BoxFit.contain)
                              : Container(
                                  color: AppColors.muted,
                                  child: const Center(
                                    child: Icon(
                                      LucideIcons.play,
                                      size: AppIconSizes.display,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                // Navigation Arrows (simplified for mobile)
                if (_hasMultipleItems)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navButton(LucideIcons.chevronLeft, () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }),
                    ),
                  ),
                if (_hasMultipleItems)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _navButton(LucideIcons.chevronRight, () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Bar
          Container(
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  spacing: 12,
                  children: [
                    _mediaDetails(),
                    if (_showReactionRow) const SizedBox(height: 16),
                    // Reactions
                    if (_showReactionRow) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 48,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: MessageReactionSummaryRow(
                                    reactions: _reactions,
                                    currentUserId: widget.currentUserId,
                                    isEnabled:
                                        !_isSubmittingReaction &&
                                        _isSocketReady,
                                    onTap: _handleReactionTap,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                                child: VerticalDivider(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _isSubmittingReaction || !_isSocketReady
                                    ? null
                                    : _openEmojiPicker,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Icon(
                                    LucideIcons.plus,
                                    size: AppIconSizes.m,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Icon(
                                  LucideIcons.share2,
                                  size: AppIconSizes.m,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Thumbnails
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: widget.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final isSelected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () => _pageController.jumpToPage(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  item.thumbnail,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: AppIconSizes.defaultSize,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _mediaDetails() {
    final item = widget.items[_currentIndex];
    final subtitle = item.sizeBytes == null
        ? item.type.toUpperCase()
        : '${formatFileSize(item.sizeBytes!)} • ${item.type.toUpperCase()}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
