import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../theme/theme.dart';
import '../widgets/header.dart';
import '../widgets/floating_message_bar.dart';
import '../widgets/snackbar.dart';
import '../models/chat.dart';
import '../services/chat.dart';

import '../constants/socket_events.dart';
import '../services/socket.dart';
import 'chat.dart';

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, required this.id});
  static const String routePath = '/thread/:id';
  final String id;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isInputVisible = true;
  bool _isLoading = true;
  final List<Message> _replies = [];
  Message? _originalMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    try {
      final result = await chatService.getMessages(widget.id);
      if (mounted) {
        setState(() {
          final items = result.items;
          if (items.isNotEmpty) {
            _originalMessage = items.first;
            _replies.addAll(items.skip(1));
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                onBack: () =>
                    context.go(ChatScreen.routePath.replaceAll(':id', '1')),
                rightElement: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.moreHorizontal,
                    size: 20,
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
                            // Original message
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
                                          borderRadius: BorderRadius.circular(50),
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
                                        _originalMessage?.senderName ?? 'Unknown',
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
                                        ? DateFormat('hh:mm a').format(
                                            _originalMessage!.createdAt,
                                          )
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
                              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                  padding: EdgeInsets.only(
                                    top: i > 0 ? 24 : 0,
                                  ),
                                  child: _reply(
                                    reply.senderAvatar ??
                                        'https://picsum.photos/seed/${reply.senderId}/100/100',
                                    reply.senderName ?? 'User',
                                    reply.content,
                                    DateFormat('hh:mm a').format(
                                      reply.createdAt,
                                    ),
                                    0,
                                    null,
                                  ),
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
              onSend: (msg, mediaIds) async {
                if (msg.trim().isNotEmpty || mediaIds.isNotEmpty) {
                  try {
                    // Send message and await acknowledgment
                    await socketService.sendMessage(
                      SocketEvents.messageCreated,
                      {
                        'content': {'text': msg, 'mediaIds': mediaIds},
                        'threadId': widget.id,
                      },
                    );

                    // Optimistic UI update or wait for broadcast
                    // For now, just a placeholder for the logic
                  } catch (e) {
                    if (!context.mounted) return;
                    AppSnackBar.show(
                      context,
                      message: 'Failed to send reply: $e',
                      type: SnackBarType.error,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _reply(
    String avatar,
    String name,
    String text,
    String time,
    int likes,
    String? photo,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              if (photo != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.saturation,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 160,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    LucideIcons.heart,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$likes',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    LucideIcons.reply,
                    size: 14,
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
