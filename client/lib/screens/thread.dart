import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/chat.dart';
import '../theme/theme.dart';
import '../widgets/floating_message_bar.dart';
import '../widgets/header.dart';
import '../widgets/snackbar.dart';
import '../services/chat.dart';
import '../services/user.dart';
import '../models/user.dart';
import 'chat.dart';
import '../widgets/media_preview.dart';

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
  bool _isInputVisible = true;
  bool _isLoading = true;
  bool _isSending = false;
  final List<Message> _replies = [];
  Message? _originalMessage;
  User? _currentUser;

  String get _parentMessageId => widget.id;
  String get _threadId => widget.threadId ?? widget.chatId ?? widget.id;

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
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    if (_isSending || (msg.trim().isEmpty && attachments.isEmpty)) return;

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
    } catch (_) {
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
        message: 'Failed to send reply',
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
    }
  }

  @override
  void dispose() {
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
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.muted,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            50,
                                          ),
                                        ),
                                        child: const Text(
                                          'ORIGINAL',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                            color: AppColors.surface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _originalMessage?.senderName ??
                                            'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _originalMessage?.content ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _originalMessage != null
                                        ? DateFormat(
                                            'hh:mm a',
                                          ).format(_originalMessage!.createdAt)
                                        : '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
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
              placeholder: 'Reply to thread...',
              onSend: _sendReply,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reply(Message reply) {
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
                  const SizedBox(width: 16),
                  const Icon(
                    LucideIcons.reply,
                    size: AppIconSizes.s,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
