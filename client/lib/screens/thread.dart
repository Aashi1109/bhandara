import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/socket_rooms.dart';
import '../models/chat.dart';
import '../theme/theme.dart';
import '../widgets/floating_message_bar.dart';
import '../widgets/header.dart';
import '../widgets/snackbar.dart';
import '../services/chat.dart';
import '../services/socket.dart';
import '../services/user.dart';
import '../constants/socket_events.dart';
import '../models/user.dart';
import '../utils/error.dart';
import 'chat.dart';
import 'explore/explore_screen.dart';
import '../widgets/media_preview.dart';
import '../widgets/message_reactions.dart';

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    required this.id,
    this.threadId,
    this.chatId,
    this.eventId,
    this.initialMessage,
  });

  static const String routePath = '/thread/:id';

  final String id;
  final String? threadId;
  final String? chatId;
  final String? eventId;
  final Message? initialMessage;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  bool _isInputVisible = true;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isThreadLocked = false;
  final List<Message> _replies = [];
  Message? _originalMessage;
  User? _currentUser;

  String get _parentMessageId => widget.id;
  String get _threadId => widget.threadId ?? widget.chatId ?? widget.id;
  String get _threadRoom => SocketRooms.thread(_threadId);

  List<MediaItem> _buildPreviewItems(List<MessageMedia> media) {
    return media
        .where((item) => item.url.isNotEmpty)
        .map(
          (item) => MediaItem(
            id: item.id.isNotEmpty ? item.id : item.url,
            url: item.url,
            thumbnail: item.url,
            type: item.type ?? 'image',
            name: 'Attachment',
          ),
        )
        .toList();
  }

  void _openMediaPreviewWithContext(
    List<MessageMedia> media, {
    int initialIndex = 0,
    String? reactionContentId,
    List<MessageReaction> initialReactions = const [],
    Future<List<MessageReaction>> Function()? loadReactions,
  }) {
    final items = _buildPreviewItems(media);
    if (items.isEmpty) {
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Media preview',
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => AppMediaPreview(
        items: items,
        initialIndex: initialIndex,
        reactionContentId: reactionContentId,
        reactionContentPath: reactionContentId != null ? 'messages' : null,
        initialReactions: initialReactions,
        currentUserId: _currentUser?.id,
        loadReactions: loadReactions,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _originalMessage = widget.initialMessage;
    _scrollController.addListener(_scrollListener);
    _loadCurrentUser();
    _loadReplies();
    _loadThreadState();
    _listenToSocketMessages();
    unawaited(_joinThreadRoom());
  }

  Future<void> _joinThreadRoom() async {
    try {
      await socketService.joinRoom(_threadRoom);
    } catch (error) {
      debugPrint('Failed to join thread room $_threadRoom: $error');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await userService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      debugPrint('Failed to load current user: $e');
    }
  }

  Future<void> _loadReplies() async {
    try {
      final results = await Future.wait<Object>([
        if (_originalMessage == null)
          chatService.getMessage(_threadId, _parentMessageId),
        chatService.getChildMessages(_threadId, _parentMessageId, limit: 100),
      ]);

      final original = _originalMessage ?? results.first as Message;
      final replyResponse = results.last as dynamic;

      if (!mounted) return;
      setState(() {
        _originalMessage = original;
        _replies
          ..clear()
          ..addAll(replyResponse.items);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load replies: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadThreadState() async {
    try {
      final thread = await chatService.getThread(_threadId);
      if (!mounted) return;
      setState(() {
        _isThreadLocked = thread.isLocked;
      });
    } catch (e) {
      debugPrint('Failed to load thread state: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isInputVisible) {
        setState(() => _isInputVisible = false);
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isInputVisible) {
        setState(() => _isInputVisible = true);
      }
    }
  }

  Future<void> _sendReply(String msg, List<ChatAttachment> attachments) async {
    if (_isThreadLocked ||
        _isSending ||
        (msg.trim().isEmpty && attachments.isEmpty)) {
      return;
    }

    final optimistic = _createOptimisticReply(msg, attachments);
    setState(() {
      _isSending = true;
      _replies.add(optimistic);
    });
    await _sendOptimisticReply(optimistic);
  }

  String _buildLocalReplyId() =>
      'local_${DateTime.now().microsecondsSinceEpoch}';

  Message _createOptimisticReply(
    String text,
    List<ChatAttachment> attachments,
  ) {
    final user = _currentUser;
    final localId = _buildLocalReplyId();
    return Message(
      id: localId,
      localId: localId,
      threadId: _threadId,
      senderId: user?.id ?? '',
      content: text.trim(),
      parentId: _parentMessageId,
      createdAt: DateTime.now(),
      senderName: user?.name ?? 'You',
      senderAvatar: user?.avatarUrl,
      media: attachments
          .map(
            (attachment) => MessageMedia(
              id: attachment.mediaId ?? '',
              url: attachment.url ?? '',
              type: attachment.isVideo ? 'video' : 'image',
            ),
          )
          .toList(),
      retryMediaIds: attachments
          .map((attachment) => attachment.mediaId)
          .whereType<String>()
          .toList(),
      localPreviewPaths: attachments
          .map((attachment) => attachment.localPath)
          .toList(),
      deliveryStatus: MessageDeliveryStatus.pending,
    );
  }

  bool _sameMediaIds(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  bool _isOptimisticMatch(Message local, Message server) {
    if (local.deliveryStatus == MessageDeliveryStatus.sent) {
      return false;
    }
    return local.threadId == server.threadId &&
        local.parentId == server.parentId &&
        local.senderId.isNotEmpty &&
        local.senderId == server.senderId &&
        local.content == server.content &&
        _sameMediaIds(local.retryMediaIds, server.retryMediaIds) &&
        local.createdAt.difference(server.createdAt).inSeconds.abs() <= 30;
  }

  Future<void> _sendOptimisticReply(Message optimistic) async {
    try {
      final reply = await chatService.sendMessage(
        _threadId,
        optimistic.content,
        mediaIds: optimistic.retryMediaIds,
        parentId: _parentMessageId,
      );

      if (!mounted) return;
      setState(() {
        final index = _replies.indexWhere(
          (r) => r.localId == optimistic.localId,
        );
        if (index != -1) {
          _replies[index] = reply;
        } else if (!_replies.any((r) => r.id == reply.id)) {
          _replies.add(reply);
        }
        _isSending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final index = _replies.indexWhere(
          (r) => r.localId == optimistic.localId,
        );
        if (index != -1) {
          _replies[index] = _replies[index].copyWith(
            deliveryStatus: MessageDeliveryStatus.failed,
          );
        }
        _isSending = false;
      });
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(error, 'Failed to send reply'),
        type: SnackBarType.error,
      );
    }
  }

  void _retryReply(Message reply) {
    final retrying = reply.copyWith(
      deliveryStatus: MessageDeliveryStatus.pending,
      createdAt: DateTime.now(),
    );
    setState(() {
      final index = _replies.indexWhere((r) => r.localId == reply.localId);
      if (index != -1) {
        _replies[index] = retrying;
        _isSending = true;
      }
    });
    _sendOptimisticReply(retrying);
  }

  void _goBack() {
    final chatId = widget.chatId ?? widget.threadId;
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (chatId != null) {
      context.go(
        ChatScreen.routePath.replaceAll(':id', chatId),
        extra: {'eventId': widget.eventId},
      );
      return;
    }
    context.go(ExploreScreen.routePath);
  }

  Future<void> _listenToSocketMessages() async {
    await _socketSubscription?.cancel();
    _socketSubscription = socketService.messages.listen((event) {
      if (!mounted) {
        return;
      }

      final eventName = event['event'] as String?;
      final eventData = event['data'];
      if (eventName == null || eventData is! Map<String, dynamic>) {
        return;
      }

      if (eventName == SocketEvents.messageCreated) {
        final message = Message.fromJson(eventData);
        if (message.threadId != _threadId) {
          return;
        }
        final optimisticIndex = _replies.indexWhere(
          (item) =>
              item.parentId == _parentMessageId &&
              _isOptimisticMatch(item, message),
        );
        if (optimisticIndex != -1) {
          setState(() {
            _replies[optimisticIndex] = message;
          });
        } else if (message.parentId == _parentMessageId &&
            !_replies.any((item) => item.id == message.id)) {
          setState(() {
            _replies.add(message);
          });
        }
        return;
      }

      if (eventName == SocketEvents.messageUpdated) {
        final message = Message.fromJson(eventData);
        if (message.threadId != _threadId) {
          return;
        }
        if (message.id == _originalMessage?.id) {
          setState(() {
            _originalMessage = message;
          });
          return;
        }
        final index = _replies.indexWhere((item) => item.id == message.id);
        if (index != -1) {
          setState(() {
            _replies[index] = message;
          });
        }
        return;
      }

      if (eventName == SocketEvents.messageDeleted) {
        final messageId = eventData['id'] as String?;
        if (eventData['threadId'] != _threadId) {
          return;
        }
        if (messageId == null) {
          return;
        }
        setState(() {
          if (_originalMessage?.id == messageId) {
            _originalMessage = null;
          }
          _replies.removeWhere((item) => item.id == messageId);
        });
        return;
      }

      if (eventName == SocketEvents.reactionCreated ||
          eventName == SocketEvents.reactionUpdated ||
          eventName == SocketEvents.reactionDeleted) {
        if (eventData['threadId'] != _threadId) {
          return;
        }
        _applyReactionEvent(eventName, eventData);
        return;
      }

      if (eventName == SocketEvents.threadLocked) {
        if (eventData['id'] == _threadId) {
          setState(() {
            _isThreadLocked = true;
          });
        }
        return;
      }

      if (eventName == SocketEvents.threadUnlocked) {
        if (eventData['id'] == _threadId) {
          setState(() {
            _isThreadLocked = false;
          });
        }
      }
    });
  }

  void _applyReactionEvent(String eventName, Map<String, dynamic> eventData) {
    if (eventData['contentPath'] != 'messages') {
      return;
    }

    final messageId = eventData['id'] as String?;
    final rawReaction = eventData['reaction'];
    if (messageId == null || rawReaction is! Map<String, dynamic>) {
      return;
    }

    final reaction = MessageReaction.fromJson(rawReaction);
    setState(() {
      if (_originalMessage?.id == messageId) {
        _originalMessage = _originalMessage?.copyWith(
          reactions: MessageReactionUtils.applySocketEvent(
            reactions: _originalMessage?.reactions ?? const [],
            eventName: eventName,
            reaction: reaction,
          ),
        );
        return;
      }

      final replyIndex = _replies.indexWhere((item) => item.id == messageId);
      if (replyIndex == -1) {
        return;
      }

      _replies[replyIndex] = _replies[replyIndex].copyWith(
        reactions: MessageReactionUtils.applySocketEvent(
          reactions: _replies[replyIndex].reactions,
          eventName: eventName,
          reaction: reaction,
        ),
      );
    });
  }

  Future<void> _toggleMessageReaction(Message message, String emoji) async {
    if (!socketService.isConnected) {
      return;
    }

    final mutation = MessageReactionUtils.createMutation(
      reactions: message.reactions,
      emoji: emoji,
      contentId: message.id,
      contentPath: 'messages',
      currentUserId: _currentUser?.id,
    );

    setState(() {
      if (_originalMessage?.id == message.id) {
        _originalMessage = _originalMessage?.copyWith(
          reactions: mutation.optimistic,
        );
        return;
      }

      final index = _replies.indexWhere((item) => item.id == message.id);
      if (index != -1) {
        _replies[index] = _replies[index].copyWith(
          reactions: mutation.optimistic,
        );
      }
    });

    try {
      await MessageReactionUtils.emitReaction(
        eventName: mutation.eventName,
        contentId: message.id,
        contentPath: 'messages',
        emoji: emoji,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_originalMessage?.id == message.id) {
          _originalMessage = _originalMessage?.copyWith(
            reactions: mutation.previous,
          );
          return;
        }

        final index = _replies.indexWhere((item) => item.id == message.id);
        if (index != -1) {
          _replies[index] = _replies[index].copyWith(
            reactions: mutation.previous,
          );
        }
      });
    }
  }

  Future<void> _showMessageReactionBar(
    BuildContext targetContext,
    Message message,
  ) {
    return showMessageReactionOverlay(
      context: context,
      targetContext: targetContext,
      currentUserReactionEmoji: MessageReactionUtils.currentUserReactionEmoji(
        message.reactions,
        _currentUser?.id,
      ),
      dismissOnScrollControllers: [_scrollController],
      onSelected: (emoji) => _toggleMessageReaction(message, emoji),
    );
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    unawaited(_leaveThreadRoom());
    super.dispose();
  }

  Future<void> _leaveThreadRoom() async {
    try {
      await socketService.leaveRoom(_threadRoom);
    } catch (error) {
      debugPrint('Failed to leave thread room $_threadRoom: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                title: 'Thread',
                onBack: _goBack,
                rightElement: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.moreHorizontal,
                    size: AppIconSizes.defaultSize,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OriginalMessageCard(
                              message: _originalMessage,
                              currentUserId: _currentUser?.id,
                              onReactionTap: _toggleMessageReaction,
                              onLongPress: (targetContext, message) =>
                                  _showMessageReactionBar(
                                    targetContext,
                                    message,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: AppColors.border,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_replies.length} REPL${_replies.length == 1 ? 'Y' : 'IES'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_replies.isEmpty)
                              const Center(
                                child: Text(
                                  'No replies yet. Be the first to reply!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              )
                            else
                              ...List.generate(_replies.length, (i) {
                                final reply = _replies[i];
                                return Padding(
                                  padding: EdgeInsets.only(top: i > 0 ? 24 : 0),
                                  child: _reply(reply),
                                );
                              }),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FloatingMessageBar(
              isVisible: _isInputVisible,
              placeholder: _isThreadLocked
                  ? 'Thread locked'
                  : 'Reply to thread...',
              onSend: _sendReply,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reply(Message reply) {
    final bubbleKey = GlobalKey();
    final imageKey = GlobalKey();
    final lane = reply.threadLaneFor(_currentUser?.id);
    final isSystemLike = lane == ThreadMessageLane.center;
    final attachmentCount = reply.media.isNotEmpty
        ? reply.media.length
        : reply.retryMediaIds.length;
    final imageMedia =
        reply.media.isNotEmpty &&
            reply.media.first.url.isNotEmpty &&
            reply.media.first.type == 'image'
        ? reply.media.first
        : null;
    final avatar = reply.senderAvatar;
    final initials = (reply.senderName?.trim().isNotEmpty ?? false)
        ? reply.senderName!
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join()
        : 'U';

    if (isSystemLike) {
      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  reply.type?.toUpperCase() ?? 'SYSTEM',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (reply.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reply.content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (avatar != null && avatar.isNotEmpty)
          ClipOval(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ),
              child: CachedNetworkImage(
                imageUrl: avatar,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                reply.senderName ?? 'User',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (imageMedia != null)
                GestureDetector(
                  key: imageKey,
                  onTap: () => _openMediaPreviewWithContext(
                    reply.media,
                    reactionContentId: reply.id,
                    initialReactions: reply.reactions,
                    loadReactions: () async {
                      final message = await chatService.getMessage(
                        _threadId,
                        reply.id,
                      );
                      return message.reactions;
                    },
                  ),
                  onLongPress: () => _showMessageReactionBar(
                    imageKey.currentContext ?? context,
                    reply,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageMedia.url,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (reply.content.isNotEmpty || attachmentCount == 0)
                GestureDetector(
                  key: bubbleKey,
                  onLongPress: () => _showMessageReactionBar(
                    bubbleKey.currentContext ?? context,
                    reply,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      reply.content.isEmpty && attachmentCount > 0
                          ? 'Media attachment'
                          : reply.content,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              if (reply.reactions.isNotEmpty)
                MessageReactionSummaryRow(
                  reactions: reply.reactions,
                  currentUserId: _currentUser?.id,
                  onTap: (emoji) => _toggleMessageReaction(reply, emoji),
                ),
              if (attachmentCount > 0) ...[
                Text(
                  '$attachmentCount attachment${attachmentCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              Row(
                spacing: 8,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(reply.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  if (reply.isPending) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'Sending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                  if (reply.hasFailed) ...[
                    GestureDetector(
                      onTap: () => _retryReply(reply),
                      child: const Row(
                        spacing: 4,
                        children: [
                          Icon(
                            LucideIcons.rotateCcw,
                            size: AppIconSizes.xs,
                            color: AppColors.error,
                          ),
                          Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Text(
                    'In thread',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginalMessageCard extends StatelessWidget {
  const _OriginalMessageCard({
    required this.message,
    required this.currentUserId,
    required this.onReactionTap,
    required this.onLongPress,
  });

  final Message? message;
  final String? currentUserId;
  final Future<void> Function(Message message, String emoji) onReactionTap;
  final Future<void> Function(BuildContext targetContext, Message message)
  onLongPress;

  @override
  Widget build(BuildContext context) {
    final contentKey = GlobalKey();
    final isSystemLike = message?.isSystemLike ?? false;
    final isCurrentUser = message?.isCurrentUser(currentUserId) ?? false;

    if (isSystemLike) {
      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              message?.content ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentUser ? 'You' : (message?.senderName ?? 'Unknown'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                key: contentKey,
                onLongPress: message == null
                    ? null
                    : () => onLongPress(
                        contentKey.currentContext ?? context,
                        message!,
                      ),
                child: Text(
                  message?.content ?? '',
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
              if (message != null && message!.reactions.isNotEmpty) ...[
                const SizedBox(height: 12),
                MessageReactionSummaryRow(
                  reactions: message!.reactions,
                  currentUserId: currentUserId,
                  onTap: (emoji) => onReactionTap(message!, emoji),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                message != null
                    ? DateFormat('hh:mm a').format(message!.createdAt)
                    : '',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
