import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/socket_rooms.dart';
import '../constants/socket_events.dart';
import '../theme/theme.dart';
import '../widgets/floating_message_bar.dart';
import 'explore/explore_screen.dart';
import 'thread.dart';
import 'event_detail.dart';
import '../services/socket.dart';
import '../services/chat.dart';
import '../services/event.dart';
import '../widgets/snackbar.dart';
import '../widgets/media_preview.dart';
import '../widgets/message_reactions.dart';
import '../models/chat.dart';
import '../services/user.dart';
import '../models/user.dart';
import '../utils/error.dart';

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
  String? _replyingToMessageId;
  String? _eventName;
  final List<Message> _messages = [];
  User? _currentUser;

  String get _threadRoom => SocketRooms.thread(widget.id);

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
    _loadEventName();
    _loadThreadState();
    _loadMessages();
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

  Future<void> _loadEventName() async {
    final eventId = widget.eventId;
    if (eventId == null || eventId.isEmpty) {
      return;
    }

    try {
      final event = await eventService.getEventPreview(eventId);
      if (!mounted) return;
      setState(() {
        _eventName = event.name.trim().isEmpty ? null : event.name.trim();
      });
    } catch (e) {
      debugPrint('Failed to load event name: $e');
    }
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
    } catch (e) {
      debugPrint('Failed to load messages: $e');
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadThreadState() async {
    try {
      final thread = await chatService.getThread(widget.id);
      if (!mounted) return;
      setState(() {
        _isThreadLocked = thread.isLocked;
      });
    } catch (e) {
      debugPrint('Failed to load thread state: $e');
    }
  }

  Future<void> _listenToSocketMessages() async {
    await _socketSubscription?.cancel();
    _socketSubscription = socketService.messages.listen((event) {
      if (!mounted) return;

      final eventName = event['event'];
      final eventData = event['data'];

      setState(() {
        if (eventName == SocketEvents.messageCreated &&
            eventData is Map<String, dynamic>) {
          final message = Message.fromJson(eventData);
          if (message.threadId != widget.id) {
            return;
          }
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
              final optimisticReplyIndex = parent.children.indexWhere(
                (child) => _isOptimisticMatch(child, message),
              );
              if (optimisticReplyIndex != -1) {
                final updatedChildren = [...parent.children];
                updatedChildren[optimisticReplyIndex] = message;
                _messages[parentIndex] = parent.copyWith(
                  children: updatedChildren,
                );
              } else if (!parent.children.any((c) => c.id == message.id)) {
                _messages[parentIndex] = parent.copyWith(
                  children: [...parent.children, message],
                );
              }
            }
          }
        } else if (eventName == SocketEvents.messageUpdated &&
            eventData is Map<String, dynamic>) {
          final updatedMsg = Message.fromJson(eventData);
          if (updatedMsg.threadId != widget.id) {
            return;
          }
          if (updatedMsg.parentId == null) {
            final index = _messages.indexWhere((m) => m.id == updatedMsg.id);
            if (index != -1) {
              _messages[index] = updatedMsg;
            }
          } else {
            _replaceReply(updatedMsg.parentId!, updatedMsg);
          }
        } else if (eventName == SocketEvents.messageDeleted &&
            eventData is Map<String, dynamic>) {
          if (eventData['threadId'] != widget.id) {
            return;
          }
          final messageId = eventData['id'];
          _messages.removeWhere((m) => m.id == messageId);
          for (var index = 0; index < _messages.length; index++) {
            _messages[index] = _messages[index].copyWith(
              children: _messages[index].children
                  .where((child) => child.id != messageId)
                  .toList(),
            );
          }
        } else if (eventName == SocketEvents.reactionCreated ||
            eventName == SocketEvents.reactionUpdated ||
            eventName == SocketEvents.reactionDeleted) {
          if (eventData is! Map<String, dynamic> ||
              eventData['threadId'] != widget.id) {
            return;
          }
          _applyReactionEvent(eventName as String, eventData);
        } else if (eventName == SocketEvents.threadLocked &&
            eventData is Map<String, dynamic>) {
          final threadId = eventData['id'];
          if (threadId == widget.id) {
            _isThreadLocked = true;
          }
        } else if (eventName == SocketEvents.threadUnlocked &&
            eventData is Map<String, dynamic>) {
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

  DateTime _nextTopLevelOptimisticTimestamp() {
    final latestTopLevel = _messages
        .where((message) => message.parentId == null)
        .map((message) => message.createdAt)
        .fold<DateTime?>(null, (latest, createdAt) {
          if (latest == null || createdAt.isAfter(latest)) {
            return createdAt;
          }
          return latest;
        });

    final now = DateTime.now();
    if (latestTopLevel == null) {
      return now;
    }

    final minimumBottom = latestTopLevel.add(const Duration(milliseconds: 1));
    return now.isAfter(minimumBottom) ? now : minimumBottom;
  }

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
      createdAt: _nextTopLevelOptimisticTimestamp(),
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
    } catch (error) {
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
        message: extractExceptionMessage(error, 'Failed to send message'),
        type: SnackBarType.error,
      );
    }
  }

  void _retryMessage(Message message) {
    final retrying = message.copyWith(
      deliveryStatus: MessageDeliveryStatus.pending,
      createdAt: _nextTopLevelOptimisticTimestamp(),
    );
    setState(() {
      final index = _messages.indexWhere((m) => m.localId == message.localId);
      if (index != -1) {
        _messages[index] = retrying;
      }
    });
    _sendOptimisticMessage(retrying);
  }

  Message _createOptimisticReply(
    Message parent,
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
      parentId: parent.id,
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

  void _replaceReply(String parentId, Message reply) {
    final parentIndex = _messages.indexWhere((item) => item.id == parentId);
    if (parentIndex == -1) {
      return;
    }

    final parent = _messages[parentIndex];
    final childIndex = parent.children.indexWhere(
      (item) => item.id == reply.id,
    );
    final updatedChildren = [...parent.children];
    if (childIndex == -1) {
      updatedChildren.add(reply);
    } else {
      updatedChildren[childIndex] = reply;
    }
    _messages[parentIndex] = parent.copyWith(children: updatedChildren);
  }

  void _markReplyFailed(String parentId, String? localId) {
    if (localId == null) {
      return;
    }

    final parentIndex = _messages.indexWhere((item) => item.id == parentId);
    if (parentIndex == -1) {
      return;
    }

    final parent = _messages[parentIndex];
    final childIndex = parent.children.indexWhere(
      (item) => item.localId == localId,
    );
    if (childIndex == -1) {
      return;
    }

    final updatedChildren = [...parent.children];
    updatedChildren[childIndex] = updatedChildren[childIndex].copyWith(
      deliveryStatus: MessageDeliveryStatus.failed,
    );
    _messages[parentIndex] = parent.copyWith(children: updatedChildren);
  }

  Future<void> _sendInlineReply(
    Message parent,
    String text,
    List<ChatAttachment> attachments,
  ) async {
    if (_isThreadLocked) return;

    final optimistic = _createOptimisticReply(parent, text, attachments);
    setState(() {
      _replyingToMessageId = null;
      _replaceReply(parent.id, optimistic);
    });

    try {
      final reply = await chatService.sendMessage(
        widget.id,
        optimistic.content,
        mediaIds: optimistic.retryMediaIds,
        parentId: parent.id,
      );
      if (!mounted) return;
      setState(() {
        _replaceReply(parent.id, reply);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _markReplyFailed(parent.id, optimistic.localId);
      });
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(error, 'Failed to send reply'),
        type: SnackBarType.error,
      );
    }
  }

  void _openThread(Message message) {
    context.push(
      ThreadScreen.routePath.replaceAll(':id', message.id),
      extra: {
        'threadId': widget.id,
        'chatId': widget.id,
        'eventId': widget.eventId,
        'message': message,
      },
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
    final typography = context.appTypography;
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
                    ? Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: typography.bodyMD.copyWith(
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
    final typography = context.appTypography;
    final subtitle = _eventName?.trim().isNotEmpty == true
        ? _eventName!
        : 'LIVE DISCUSSION';

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
                  style: typography.titleMD,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.overline,
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
    final typography = context.appTypography;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(text.toUpperCase(), style: typography.overline),
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
    if (messageIndex != -1) {
      final reaction = MessageReaction.fromJson(rawReaction);
      final reactions = MessageReactionUtils.applySocketEvent(
        reactions: _messages[messageIndex].reactions,
        eventName: eventName,
        reaction: reaction,
      );

      _messages[messageIndex] = _messages[messageIndex].copyWith(
        reactions: reactions,
      );
      return;
    }

    final reaction = MessageReaction.fromJson(rawReaction);
    for (var index = 0; index < _messages.length; index++) {
      final childIndex = _messages[index].children.indexWhere(
        (child) => child.id == messageId,
      );
      if (childIndex == -1) {
        continue;
      }

      final updatedChildren = [..._messages[index].children];
      updatedChildren[childIndex] = updatedChildren[childIndex].copyWith(
        reactions: MessageReactionUtils.applySocketEvent(
          reactions: updatedChildren[childIndex].reactions,
          eventName: eventName,
          reaction: reaction,
        ),
      );
      _messages[index] = _messages[index].copyWith(children: updatedChildren);
      return;
    }
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

    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index == -1) {
      return;
    }

    setState(() {
      _messages[index] = _messages[index].copyWith(
        reactions: mutation.optimistic,
      );
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
        _messages[index] = _messages[index].copyWith(
          reactions: mutation.previous,
        );
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

  Widget _buildInlineReplyComposer(Message parent) {
    final typography = context.appTypography;
    final replyingTo = parent.senderName?.trim().isNotEmpty == true
        ? parent.senderName!
        : 'this message';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Replying to $replyingTo',
                  style: typography.bodyXS,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _replyingToMessageId = null),
                child: const Icon(
                  LucideIcons.x,
                  size: AppIconSizes.s,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FloatingMessageBar(
            isVisible: true,
            padding: EdgeInsets.zero,
            placeholder: 'Reply in thread...',
            onSend: (message, attachments) =>
                _sendInlineReply(parent, message, attachments),
          ),
        ],
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
    final typography = context.appTypography;
    final bubbleKey = GlobalKey();
    final imageKey = GlobalKey();
    final isPending = status == MessageDeliveryStatus.pending;
    final isFailed = status == MessageDeliveryStatus.failed;
    final lane =
        threadMessage?.chatLaneFor(_currentUser?.id) ?? ChatMessageLane.left;
    final isCurrentUser = lane == ChatMessageLane.right;
    final isSystemLike = lane == ChatMessageLane.center;
    final crossAxisAlignment = isCurrentUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleAlignment = isCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final timeLabel = Text(time, style: typography.overline);
    final metadataChildren = <Widget>[
      if (!isCurrentUser) timeLabel,
      if (isPending)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text('Sending', style: typography.labelSM),
          ],
        ),
      if (isFailed && onRetry != null)
        GestureDetector(
          onTap: onRetry,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.rotateCcw,
                size: AppIconSizes.xs,
                color: AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                'Retry',
                style: typography.labelSM.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ),
      if (threadMessage != null && isCurrentUser)
        GestureDetector(
          onTap: () => _openThread(threadMessage),
          child: Text(
            'Start thread',
            style: typography.labelSMStrong.copyWith(color: AppColors.primary),
          ),
        ),
      if (threadMessage != null && !isCurrentUser)
        GestureDetector(
          onTap: _isThreadLocked
              ? null
              : () => setState(() {
                  _replyingToMessageId =
                      _replyingToMessageId == threadMessage.id
                      ? null
                      : threadMessage.id;
                }),
          child: Text(
            _replyingToMessageId == threadMessage.id ? 'Cancel reply' : 'Reply',
            style: typography.labelSMStrong.copyWith(
              color: _isThreadLocked
                  ? AppColors.mutedForeground
                  : AppColors.primary,
            ),
          ),
        ),
      if (isCurrentUser) timeLabel,
    ];
    final imageMedia =
        media.isNotEmpty &&
            media.first.url.isNotEmpty &&
            media.first.type == 'image'
        ? media.first
        : null;
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  badge ?? name,
                  textAlign: TextAlign.center,
                  style: typography.overlineEmphasis,
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: typography.bodyBaseSemi.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(time, style: typography.overline),
              ],
            ),
          ),
        ),
      );
    }

    final contentColumn = Column(
      crossAxisAlignment: crossAxisAlignment,
      spacing: 6,
      children: [
        if (imageMedia != null)
          Align(
            alignment: bubbleAlignment,
            child: GestureDetector(
              key: imageKey,
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
              onLongPress: threadMessage == null
                  ? null
                  : () {
                      final targetContext = imageKey.currentContext;
                      if (targetContext != null) {
                        _showMessageReactionBar(targetContext, threadMessage);
                      }
                    },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  imageMedia.url,
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        if (text.isNotEmpty || attachmentCount == 0)
          Align(
            alignment: bubbleAlignment,
            child: GestureDetector(
              key: bubbleKey,
              onLongPress: threadMessage == null
                  ? null
                  : () {
                      final targetContext = bubbleKey.currentContext;
                      if (targetContext != null) {
                        _showMessageReactionBar(targetContext, threadMessage);
                      }
                    },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrentUser ? AppColors.primary : AppColors.muted,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isCurrentUser ? 20 : 8),
                    topRight: Radius.circular(isCurrentUser ? 8 : 20),
                    bottomLeft: const Radius.circular(20),
                    bottomRight: const Radius.circular(20),
                  ),
                  border: Border.all(
                    color: isCurrentUser ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  text.isEmpty && attachmentCount > 0
                      ? 'Media attachment'
                      : text,
                  style: typography.bodyMD.copyWith(
                    color: isCurrentUser
                        ? AppColors.surface
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        if (threadMessage != null && threadMessage.reactions.isNotEmpty)
          MessageReactionSummaryRow(
            reactions: threadMessage.reactions,
            currentUserId: _currentUser?.id,
            onTap: (emoji) => _toggleMessageReaction(threadMessage, emoji),
          ),
        if (attachmentCount > 0)
          Text(
            '$attachmentCount attachment${attachmentCount == 1 ? '' : 's'}',
            style: typography.labelSM,
          ),
        Wrap(
          alignment: isCurrentUser ? WrapAlignment.end : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: metadataChildren,
        ),
        if (threadMessage != null && _replyingToMessageId == threadMessage.id)
          _buildInlineReplyComposer(threadMessage),
        if (hasThread && threadMessage != null)
          GestureDetector(
            onTap: () => _openThread(threadMessage),
            child: _buildThreadCard(threadMessage),
          ),
      ],
    );

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: contentColumn,
      ),
    );
  }

  Widget _buildThreadCard(Message message) {
    final typography = context.appTypography;
    final replyCount = message.children.length;
    final latestReply = replyCount > 0 ? message.children.last : null;
    final previewText = latestReply == null
        ? 'Open replies'
        : latestReply.content.isNotEmpty
        ? latestReply.content
        : 'Attachment reply';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('THREAD', style: typography.overlineStrong),
              const Icon(
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
                child: Text('Original', style: typography.labelXS),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$replyCount repl${replyCount == 1 ? 'y' : 'ies'}',
                  style: typography.bodySMStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            previewText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: typography.bodyBaseSemi.copyWith(color: AppColors.primary),
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
    final typography = context.appTypography;
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
                  style: typography.bodyMDStrong.copyWith(
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
            Text(time, style: typography.overline),
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
