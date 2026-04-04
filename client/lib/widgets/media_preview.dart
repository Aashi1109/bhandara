import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/video_player.dart';

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
    final typography = context.appTypography;
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
              config: Config(
                height: 320,
                checkPlatformCompatibility: true,
                emojiViewConfig: const EmojiViewConfig(
                  backgroundColor: AppColors.surface,
                  columns: 8,
                ),
                categoryViewConfig: const CategoryViewConfig(
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
                  inputTextStyle: typography.bodyMDSemi.copyWith(
                    color: AppColors.primary,
                  ),
                  hintTextStyle: typography.bodyMD.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
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
    final typography = context.appTypography;
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
                      style: typography.overline.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} OF ${widget.items.length}',
                      style: typography.labelSM.copyWith(
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
                              : _VideoPreviewCard(
                                  key: ValueKey(item.id),
                                  url: item.url,
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
    final typography = context.appTypography;
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
                style: typography.labelMD.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: typography.bodySM.copyWith(
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

class _VideoPreviewCard extends StatefulWidget {
  const _VideoPreviewCard({super.key, required this.url});

  final String url;

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard> {
  static const List<double> _playbackSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  VideoPlayerController? _controller;
  Timer? _hideControlsTimer;
  bool _showControls = true;
  bool _isMuted = false;
  bool _fitToFill = false;
  double _playbackSpeed = 1.0;

  VideoPlayerValue? get _value => _controller?.value;
  bool get _isReady => _value?.isInitialized ?? false;
  Duration get _position => _value?.position ?? Duration.zero;
  Duration get _duration => _value?.duration ?? Duration.zero;
  bool get _isPlaying => _value?.isPlaying ?? false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onControllerUpdated);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller.addListener(_onControllerUpdated);

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1);
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (!mounted) return;
      setState(() {});
      _scheduleControlsHide();
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  void _onControllerUpdated() {
    if (!mounted) return;
    setState(() {});
  }

  void _scheduleControlsHide() {
    _hideControlsTimer?.cancel();
    if (!_isPlaying) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showControls = false;
      });
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    if (_isPlaying) {
      await controller.pause();
      _hideControlsTimer?.cancel();
    } else {
      await controller.play();
      _scheduleControlsHide();
    }

    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > _duration
        ? _duration
        : target;
    await controller.seekTo(clamped);
    _showControlsTemporarily();
  }

  Future<void> _setPosition(double millis) async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    await controller.seekTo(Duration(milliseconds: millis.round()));
    _showControlsTemporarily();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (!mounted) return;
    setState(() {
      _isMuted = nextMuted;
    });
    _showControlsTemporarily();
  }

  Future<void> _cyclePlaybackSpeed() async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    final currentIndex = _playbackSpeeds.indexOf(_playbackSpeed);
    final nextIndex =
        currentIndex == -1 || currentIndex == _playbackSpeeds.length - 1
        ? 0
        : currentIndex + 1;
    final nextSpeed = _playbackSpeeds[nextIndex];
    await controller.setPlaybackSpeed(nextSpeed);
    if (!mounted) return;
    setState(() {
      _playbackSpeed = nextSpeed;
    });
    _showControlsTemporarily();
  }

  void _toggleFit() {
    setState(() {
      _fitToFill = !_fitToFill;
    });
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _scheduleControlsHide();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    if (!_isReady) {
      return Container(
        color: AppColors.muted,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final controller = _controller!;
    final progressMax = _duration.inMilliseconds <= 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final progressValue = _position.inMilliseconds
        .toDouble()
        .clamp(0.0, progressMax)
        .toDouble();

    return GestureDetector(
      onTap: _showControlsTemporarily,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF081117),
            child: FittedBox(
              fit: _fitToFill ? BoxFit.cover : BoxFit.contain,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showControls ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.52),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showControls)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: _togglePlayback,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      _isPlaying ? LucideIcons.pause : LucideIcons.play,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showControls ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3238).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _controlIcon(
                      icon: _isPlaying ? LucideIcons.pause : LucideIcons.play,
                      onTap: _togglePlayback,
                    ),
                    const SizedBox(width: 12),
                    _controlIcon(
                      icon: LucideIcons.rotateCcw,
                      onTap: () => _seekBy(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 8),
                    _controlIcon(
                      icon: LucideIcons.rotateCw,
                      onTap: () => _seekBy(const Duration(seconds: 10)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(_position),
                      style: typography.bodySM.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.28,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: progressValue,
                          min: 0,
                          max: progressMax,
                          onChanged: _setPosition,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(_duration),
                      style: typography.bodySM.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _cyclePlaybackSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_playbackSpeed.toStringAsFixed(_playbackSpeed.truncateToDouble() == _playbackSpeed ? 0 : 2)}x',
                          style: typography.bodySM.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _controlIcon(
                      icon: _isMuted
                          ? LucideIcons.volumeX
                          : LucideIcons.volume2,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 8),
                    _controlIcon(
                      icon: _fitToFill
                          ? LucideIcons.minimize
                          : LucideIcons.maximize,
                      onTap: _toggleFit,
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

  Widget _controlIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}
