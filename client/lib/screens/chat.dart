import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/socket_events.dart';
import '../theme/theme.dart';
import '../widgets/floating_message_bar.dart';
import 'explore.dart';
import 'thread.dart';
import 'event_detail.dart';
import '../services/socket.dart';
import '../services/chat.dart';
import '../widgets/snackbar.dart';
import '../widgets/media_preview.dart';
import '../models/chat.dart';
import 'package:intl/intl.dart';
import '../services/user.dart';
import '../models/user.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.id, this.eventId});

  static const String routePath = '/chat/:id';
  final String id;
  final String? eventId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  bool _isInputVisible = true;
  bool _isThreadLocked = false;
  bool _isLoadingMessages = true;
  final List<Message> _messages = [];
  User? _currentUser;

  List<_ChatMessageGroup> get _messageGroups {
    if (_messages.isEmpty) {
      return const [];
    }

    final sorted = [..._messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final groups = <_ChatMessageGroup>[];

    for (final message in sorted) {
      if (groups.isEmpty || !_isSameDay(groups.last.date, message.createdAt)) {
        groups.add(
          _ChatMessageGroup(date: message.createdAt, messages: [message]),
        );
      } else {
        groups.last.messages.add(message);
      }
    }

    return groups;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadCurrentUser();
    _loadMessages();
    _listenToSocketMessages();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await userService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final result = await chatService.getMessages(widget.id);
      if (mounted) {
        setState(() {
          _messages.addAll(result.items);
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _listenToSocketMessages() async {
    await _socketSubscription?.cancel();
    _socketSubscription = socketService.messages.listen((event) {
      if (!mounted) return;

      final eventName = event['event'];
      final eventData = event['data'];

      setState(() {
        if (eventName == SocketEvents.messageCreated) {
          final message = Message.fromJson(eventData);
          final optimisticIndex = _messages.indexWhere(
            (m) => m.parentId == null && _isOptimisticMatch(m, message),
          );
          if (optimisticIndex != -1) {
            _messages[optimisticIndex] = message;
          } else if (message.parentId == null &&
              !_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
            _scrollToBottom();
          } else if (message.parentId != null) {
            final parentIndex = _messages.indexWhere(
              (m) => m.id == message.parentId,
            );
            if (parentIndex != -1) {
              final parent = _messages[parentIndex];
              final hasReply = parent.children.any((c) => c.id == message.id);
              if (!hasReply) {
                _messages[parentIndex] = parent.copyWith(
                  children: [...parent.children, message],
                );
              }
            }
          }
        } else if (eventName == SocketEvents.messageUpdated) {
          final updatedMsg = Message.fromJson(eventData);
          final index = _messages.indexWhere((m) => m.id == updatedMsg.id);
          if (index != -1) {
            _messages[index] = updatedMsg;
          }
        } else if (eventName == SocketEvents.messageDeleted) {
          final messageId = eventData['id'];
          _messages.removeWhere((m) => m.id == messageId);
        } else if (eventName == SocketEvents.reactionCreated ||
            eventName == SocketEvents.reactionUpdated ||
            eventName == SocketEvents.reactionDeleted) {
          _applyReactionEvent(
            eventName as String,
            eventData as Map<String, dynamic>,
          );
        } else if (eventName == SocketEvents.threadLocked) {
          final threadId = eventData['id'];
          if (threadId == widget.id) {
            _isThreadLocked = true;
          }
        } else if (eventName == SocketEvents.threadUnlocked) {
          final threadId = eventData['id'];
          if (threadId == widget.id) {
            _isThreadLocked = false;
          }
        }
      });
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isInputVisible) {
        setState(() {
          _isInputVisible = false;
        });
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isInputVisible) {
        setState(() {
          _isInputVisible = true;
        });
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final eventId = widget.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      context.go(EventDetailScreen.routePath.replaceAll(':id', eventId));
      return;
    }

    context.go(ExploreScreen.routePath);
  }

  String _buildLocalMessageId() =>
      'local_${DateTime.now().microsecondsSinceEpoch}';

  Message _createOptimisticMessage(
    String text,
    List<ChatAttachment> attachments,
  ) {
    final user = _currentUser;
    final localId = _buildLocalMessageId();
    return Message(
      id: localId,
      localId: localId,
      threadId: widget.id,
      senderId: user?.id ?? '',
      content: text.trim(),
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
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _isOptimisticMatch(Message local, Message server) {
    if (local.deliveryStatus == MessageDeliveryStatus.sent) return false;
    return local.threadId == server.threadId &&
        local.parentId == server.parentId &&
        local.senderId.isNotEmpty &&
        local.senderId == server.senderId &&
        local.content == server.content &&
        _sameMediaIds(local.retryMediaIds, server.retryMediaIds) &&
        local.createdAt.difference(server.createdAt).inSeconds.abs() <= 30;
  }

  Future<void> _sendOptimisticMessage(Message optimistic) async {
    try {
      final message = await chatService.sendMessage(
        widget.id,
        optimistic.content,
        mediaIds: optimistic.retryMediaIds,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.localId == optimistic.localId,
        );
        if (index != -1) {
          _messages[index] = message;
        } else if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.localId == optimistic.localId,
        );
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            deliveryStatus: MessageDeliveryStatus.failed,
          );
        }
      });
      AppSnackBar.show(
        context,
        message: 'Failed to send message',
        type: SnackBarType.error,
      );
    }
  }

  void _retryMessage(Message message) {
    final retrying = message.copyWith(
      deliveryStatus: MessageDeliveryStatus.pending,
      createdAt: DateTime.now(),
    );
    setState(() {
      final index = _messages.indexWhere((m) => m.localId == message.localId);
      if (index != -1) {
        _messages[index] = retrying;
      }
    });
    _sendOptimisticMessage(retrying);
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoadingMessages
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          ..._messageGroups.expand(
                            (group) => [
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _ChatDateHeaderDelegate(
                                  child: _buildTimestamp(
                                    _formatStickyDate(group.date),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  12,
                                  24,
                                  0,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final msg = group.messages[index];
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        top: index == 0 ? 0 : 32,
                                        bottom:
                                            index == group.messages.length - 1
                                            ? 24
                                            : 0,
                                      ),
                                      child: _renderMessage(msg),
                                    );
                                  }, childCount: group.messages.length),
                                ),
                              ),
                            ],
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 120),
                          ),
                        ],
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
              onSend: (msg, attachments) async {
                if (_isThreadLocked) return;
                if (msg.trim().isNotEmpty || attachments.isNotEmpty) {
                  final optimistic = _createOptimisticMessage(msg, attachments);
                  setState(() {
                    _messages.add(optimistic);
                  });
                  _scrollToBottom();
                  await _sendOptimisticMessage(optimistic);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.arrowLeft,
                size: AppIconSizes.defaultSize,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isThreadLocked ? 'Thread (Locked)' : 'Live Discussion',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'LIVE DISCUSSION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  LucideIcons.bell,
                  size: AppIconSizes.defaultSize,
                  color: AppColors.primary,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.moreHorizontal,
              size: AppIconSizes.defaultSize,
              color: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderMessage(Message msg) {
    final attachmentCount = msg.media.isNotEmpty
        ? msg.media.length
        : msg.retryMediaIds.length;
    return _buildMessage(
      name: msg.senderName ?? 'User',
      initials: msg.senderName?.split(' ').map((e) => e[0]).join('') ?? 'U',
      imageUrl: msg.senderAvatar,
      text: msg.content,
      time: DateFormat('hh:mm a').format(msg.createdAt),
      hasThread: msg.children.isNotEmpty,
      threadMessage: msg,
      status: msg.deliveryStatus,
      onRetry: msg.hasFailed ? () => _retryMessage(msg) : null,
      media: msg.media,
      attachmentCount: attachmentCount,
    );
  }

  Widget _buildTimestamp(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatStickyDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(now, date)) {
      return 'Today';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(yesterday, date)) {
      return 'Yesterday';
    }

    return DateFormat('MMMM dd, yyyy').format(date);
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

    final messageIndex = _messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (messageIndex == -1) {
      return;
    }

    final reaction = MessageReaction.fromJson(rawReaction);
    final reactions = List<MessageReaction>.from(
      _messages[messageIndex].reactions,
    );

    switch (eventName) {
      case SocketEvents.reactionCreated:
      case SocketEvents.reactionUpdated:
        final sameIdIndex = reactions.indexWhere(
          (item) => item.id == reaction.id,
        );
        final sameUserIndex = reactions.indexWhere(
          (item) => item.userId == reaction.userId,
        );
        if (sameIdIndex != -1) {
          reactions[sameIdIndex] = reaction;
        } else if (sameUserIndex != -1) {
          reactions[sameUserIndex] = reaction;
        } else {
          reactions.add(reaction);
        }
        break;
      case SocketEvents.reactionDeleted:
        reactions.removeWhere((item) => item.id == reaction.id);
        break;
    }

    _messages[messageIndex] = _messages[messageIndex].copyWith(
      reactions: reactions,
    );
  }

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

  void _openMediaPreview(
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

  Widget _buildMessage({
    required String name,
    String? initials,
    String? imageUrl,
    String? badge,
    required String text,
    required String time,
    bool hasThread = false,
    Message? threadMessage,
    MessageDeliveryStatus status = MessageDeliveryStatus.sent,
    VoidCallback? onRetry,
    List<MessageMedia> media = const [],
    int attachmentCount = 0,
  }) {
    final isPending = status == MessageDeliveryStatus.pending;
    final isFailed = status == MessageDeliveryStatus.failed;
    final imageMedia =
        media.isNotEmpty &&
            media.first.url.isNotEmpty &&
            media.first.type == 'image'
        ? media.first
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.muted,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            image: imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: imageUrl == null
              ? Text(
                  initials ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Row(
                spacing: 8,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
              if (imageMedia != null)
                GestureDetector(
                  onTap: () => _openMediaPreview(
                    media,
                    reactionContentId: threadMessage?.id,
                    initialReactions: threadMessage?.reactions ?? const [],
                    loadReactions: threadMessage == null
                        ? null
                        : () async {
                            final message = await chatService.getMessage(
                              widget.id,
                              threadMessage.id,
                            );
                            return message.reactions;
                          },
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
              if (text.isNotEmpty || attachmentCount == 0)
                Container(
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
                    text.isEmpty && attachmentCount > 0
                        ? 'Media attachment'
                        : text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
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
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  if (isPending) ...[
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
                  if (isFailed && onRetry != null) ...[
                    GestureDetector(
                      onTap: onRetry,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
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
                  if (hasThread) ...[
                    GestureDetector(
                      onTap: () => context.push(
                        ThreadScreen.routePath.replaceAll(
                          ':id',
                          threadMessage!.id,
                        ),
                        extra: {
                          'threadId': widget.id,
                          'chatId': widget.id,
                          'eventId': widget.eventId,
                          'message': threadMessage,
                        },
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          Text(
                            'Reply to thread',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Icon(
                            LucideIcons.messageSquare,
                            size: AppIconSizes.xs,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (hasThread) ...[
                GestureDetector(
                  onTap: () => context.push(
                    ThreadScreen.routePath.replaceAll(':id', threadMessage!.id),
                    extra: {
                      'threadId': widget.id,
                      'chatId': widget.id,
                      'eventId': widget.eventId,
                      'message': threadMessage,
                    },
                  ),
                  child: _buildThreadCard(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThreadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THREAD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.mutedForeground,
                ),
              ),
              Icon(
                LucideIcons.externalLink,
                size: AppIconSizes.xs,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Original',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Open replies',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 24,
                child: Stack(
                  children: List.generate(4, (index) {
                    if (index == 3) {
                      return Positioned(
                        left: index * 14.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '+2',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    }
                    return Positioned(
                      left: index * 14.0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://picsum.photos/seed/thread/50/50',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildImageMessage({
    required String imageUrl,
    required String caption,
    required String time,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.transparent,
                        AppColors.primary.withValues(alpha: 0.54),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.26),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surface.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    size: AppIconSizes.m,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Text('❤️'),
                  SizedBox(width: 4),
                  Text('👍'),
                  SizedBox(width: 4),
                  Text('🔥'),
                  SizedBox(width: 4),
                  Text('🤤'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChatMessageGroup {
  const _ChatMessageGroup({required this.date, required this.messages});

  final DateTime date;
  final List<Message> messages;
}

class _ChatDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ChatDateHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.92),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ChatDateHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
