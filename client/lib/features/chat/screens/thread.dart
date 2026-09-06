import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/constants/socket_rooms.dart';
import '../models/chat.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/floating_message_bar.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/snackbar.dart';
import '../services/chat.dart';
import '../../../shared/services/socket.dart';
import '../../profile/services/user.dart';
import '../../../shared/constants/socket_events.dart';
import '../../profile/models/user.dart';
import '../../../shared/utils/error.dart';
import './chat.dart';
import '../../explore/screens/explore_screen.dart';
import '../../events/widgets/media_preview.dart';
import '../widgets/message_reactions.dart';
import '../../../shared/widgets/skeleton.dart';

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
      final rawEventData = event['data'];
      final eventData = _extractSocketPayload(rawEventData);
      if (eventName == null || eventData == null) {
        return;
      }

      if (eventName == SocketEvents.messageCreate) {
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

      if (eventName == SocketEvents.messageUpdate) {
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

      if (eventName == SocketEvents.messageDelete) {
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

      if (eventName == SocketEvents.reactionCreate ||
          eventName == SocketEvents.reactionUpdate ||
          eventName == SocketEvents.reactionDelete) {
        if (eventData['threadId'] != _threadId) {
          return;
        }
        _applyReactionEvent(eventName, eventData);
        return;
      }

      if (eventName == SocketEvents.threadDelete) {
        if (eventData['id'] == _threadId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _goBack();
            }
          });
        }
        return;
      }

      if (eventName == SocketEvents.threadLock) {
        if (eventData['id'] == _threadId) {
          setState(() {
            _isThreadLocked = true;
          });
        }
        return;
      }

      if (eventName == SocketEvents.threadUnlock) {
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

  Map<String, dynamic>? _extractSocketPayload(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final nested = payload['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return payload;
    }

    if (payload is Map) {
      final castPayload = Map<String, dynamic>.from(payload);
      final nested = castPayload['data'];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
      return castPayload;
    }

    return null;
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

  Widget _buildLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appPalette.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppSkeleton(width: 40, height: 40, shape: BoxShape.circle),
                  SizedBox(width: 12),
                  Expanded(child: AppSkeletonLine(width: 108, height: 14)),
                ],
              ),
              SizedBox(height: 14),
              AppSkeleton(
                height: 88,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppSkeletonLine(width: 72, height: 12),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 40, height: 40, shape: BoxShape.circle),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonLine(width: 92, height: 14),
                      SizedBox(height: 10),
                      AppSkeleton(
                        height: 72,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      SizedBox(height: 8),
                      AppSkeletonLine(width: 64, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPalette.surface,
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
                  decoration: BoxDecoration(
                    color: context.appPalette.muted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.moreHorizontal,
                    size: AppIconSizes.defaultSize,
                    color: context.appPalette.primary,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
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
                                    color: context.appPalette.border,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_replies.length} REPL${_replies.length == 1 ? 'Y' : 'IES'}',
                                    style: context.appTypography.overline,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_replies.isEmpty)
                              Center(
                                child: Text(
                                  'No replies yet. Be the first to reply!',
                                  style: context.appTypography.bodyMD.copyWith(
                                    color: context.appPalette.mutedForeground,
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
    final typography = context.appTypography;
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
              color: context.appPalette.muted,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appPalette.border),
            ),
            child: Column(
              children: [
                Text(
                  reply.type?.toUpperCase() ?? 'SYSTEM',
                  style: typography.overlineEmphasis,
                ),
                if (reply.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reply.content,
                    textAlign: TextAlign.center,
                    style: typography.bodyBaseSemi.copyWith(
                      color: context.appPalette.primary,
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
            decoration: BoxDecoration(
              color: context.appPalette.muted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: typography.bodySMStrong.copyWith(color: context.appPalette.primary),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                reply.senderName ?? 'User',
                style: typography.labelMD.copyWith(color: context.appPalette.primary),
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
                      color: context.appPalette.muted,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(color: context.appPalette.border),
                    ),
                    child: Text(
                      reply.content.isEmpty && attachmentCount > 0
                          ? 'Media attachment'
                          : reply.content,
                      style: typography.bodyMD,
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
                  style: typography.captionSM.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
              Row(
                spacing: 8,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(reply.createdAt),
                    style: typography.labelSM.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                  if (reply.isPending) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appPalette.primary,
                      ),
                    ),
                    Text(
                      'Sending',
                      style: typography.labelSM.copyWith(
                        color: context.appPalette.mutedForeground,
                      ),
                    ),
                  ],
                  if (reply.hasFailed) ...[
                    GestureDetector(
                      onTap: () => _retryReply(reply),
                      child: Row(
                        spacing: 4,
                        children: [
                          Icon(
                            LucideIcons.rotateCcw,
                            size: AppIconSizes.xs,
                            color: context.appPalette.error,
                          ),
                          Text(
                            'Retry',
                            style: typography.labelSM.copyWith(
                              color: context.appPalette.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'In thread',
                    style: typography.labelSMStrong.copyWith(
                      color: context.appPalette.mutedForeground,
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
    final typography = context.appTypography;
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
              color: context.appPalette.muted,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appPalette.border),
            ),
            child: Text(
              message?.content ?? '',
              textAlign: TextAlign.center,
              style: typography.bodyMDSemi.copyWith(color: context.appPalette.primary),
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
            color: context.appPalette.muted,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: context.appPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(
                isCurrentUser ? 'You' : (message?.senderName ?? 'Unknown'),
                style: typography.labelMD.copyWith(color: context.appPalette.primary),
              ),
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
                  style: typography.bodyMD,
                ),
              ),
              if (message != null && message!.reactions.isNotEmpty) ...[
                MessageReactionSummaryRow(
                  reactions: message!.reactions,
                  currentUserId: currentUserId,
                  onTap: (emoji) => onReactionTap(message!, emoji),
                ),
              ],
              Text(
                message != null
                    ? DateFormat('hh:mm a').format(message!.createdAt)
                    : '',
                textAlign: TextAlign.left,
                style: typography.labelSM.copyWith(
                  color: context.appPalette.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
