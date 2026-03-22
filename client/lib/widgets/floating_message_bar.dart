import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_attachment.dart';
import '../theme/theme.dart';
import '../services/file.dart';
import 'attachment_pill.dart';
import 'snackbar.dart';

export '../models/chat_attachment.dart';

class FloatingMessageBar extends StatefulWidget {
  const FloatingMessageBar({
    super.key,
    this.placeholder = 'Add a reply...',
    required this.onSend,
    this.isVisible = true,
  });

  final String placeholder;
  final Function(String message, List<ChatAttachment> attachments) onSend;
  final bool isVisible;

  @override
  State<FloatingMessageBar> createState() => _FloatingMessageBarState();
}

class _FloatingMessageBarState extends State<FloatingMessageBar> {
  static const _emojiToggleKey = ValueKey('floating_message_bar_emoji_toggle');
  static const _emojiPickerKey = ValueKey('floating_message_bar_emoji_picker');

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatAttachment> _attachments = [];
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }
  }

  void _handleSend() {
    final allUploaded = _attachments.every(
      (a) => a.mediaId != null && !a.isUploading,
    );
    if (!allUploaded) return;

    if (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty) {
      widget.onSend(
        _controller.text,
        _attachments.map((attachment) => attachment.copyWith()).toList(),
      );
      _controller.clear();
      setState(() {
        _attachments.clear();
        _showEmojiPicker = false;
      });
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
      _focusNode.requestFocus();
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _showEmojiPicker = true;
    });
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(0, text.length);
    final replacementStart = safeStart < safeEnd ? safeStart : safeEnd;
    final replacementEnd = safeStart < safeEnd ? safeEnd : safeStart;

    final newText = text.replaceRange(replacementStart, replacementEnd, emoji);
    final newOffset = replacementStart + emoji.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    setState(() {});
  }

  Future<void> _pickMedia(bool isVideo) async {
    if (_attachments.length >= 5) return;

    try {
      final XFile? file = isVideo
          ? await fileService.pickVideo()
          : await fileService.pickImage();

      if (file == null) return;

      final attachment = ChatAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.name,
        localPath: file.path,
        sizeBytes: await file.length(),
        isVideo: isVideo,
        isUploading: true,
      );

      setState(() {
        _attachments.add(attachment);
      });

      await _uploadAttachment(attachment);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: e.toString(),
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _uploadAttachment(ChatAttachment attachment) async {
    try {
      final mediaId = await fileService.uploadFile(
        XFile(attachment.localPath, name: attachment.name),
      );
      final media = mediaId != null ? await fileService.getMediaById(mediaId) : null;
      final previewUrl = (media?['publicUrl'] ?? media?['url']) as String?;

      if (!mounted) return;
      setState(() {
        final index = _attachments.indexWhere((a) => a.id == attachment.id);
        if (index != -1) {
          _attachments[index] = _attachments[index].copyWith(
            mediaId: mediaId,
            url: previewUrl,
            isUploading: false,
            hasFailed: false,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        final index = _attachments.indexWhere((a) => a.id == attachment.id);
        if (index != -1) {
          _attachments[index] = _attachments[index].copyWith(
            isUploading: false,
            hasFailed: true,
          );
        }
      });

      AppSnackBar.show(
        context,
        message: 'Upload failed',
        type: SnackBarType.error,
      );
    }
  }

  void _retryAttachment(ChatAttachment attachment) {
    setState(() {
      final index = _attachments.indexWhere((a) => a.id == attachment.id);
      if (index != -1) {
        _attachments[index] = _attachments[index].copyWith(
          isUploading: true,
          hasFailed: false,
        );
      }
    });

    _uploadAttachment(attachment);
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((a) => a.id == id);
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
        _attachments.every((a) => !a.isUploading);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnimatedSlide(
      offset: widget.isVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final actionSize = isCompact ? 36.0 : 38.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 24,
                0,
                isCompact ? 16 : 24,
                bottomInset + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attachment Chips
                  if (_attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments.map((file) {
                          return _buildAttachmentChip(file);
                        }).toList(),
                      ),
                    ),

                  if (_showEmojiPicker) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          key: _emojiPickerKey,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: EmojiPicker(
                            onEmojiSelected: (_, emoji) {
                              _insertEmoji(emoji.emoji);
                            },
                            config: const Config(
                              height: 256,
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
                              bottomActionBarConfig: BottomActionBarConfig(
                                backgroundColor: AppColors.surface,
                                buttonColor: AppColors.muted,
                                buttonIconColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Message Bar Pill
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 6 : 8,
                      vertical: isCompact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      spacing: isCompact ? 4 : 6,
                      children: [
                        PopupMenuButton<bool>(
                          onSelected: _pickMedia,
                          padding: EdgeInsets.zero,
                          offset: const Offset(0, -140),
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: false,
                              child: ListTile(
                                leading: Icon(
                                  LucideIcons.image,
                                  size: AppIconSizes.defaultSize,
                                ),
                                title: Text('Image'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const PopupMenuItem(
                              value: true,
                              child: ListTile(
                                leading: Icon(
                                  LucideIcons.video,
                                  size: AppIconSizes.defaultSize,
                                ),
                                title: Text('Video (Max 10MB)'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                          child: Container(
                            width: actionSize,
                            height: actionSize,
                            decoration: const BoxDecoration(
                              color: AppColors.muted,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.plus,
                              size: AppIconSizes.defaultSize,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: (val) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: widget.placeholder,
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedForeground.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 4 : 8,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          key: _emojiToggleKey,
                          onTap: _toggleEmojiPicker,
                          child: SizedBox(
                            width: actionSize,
                            height: actionSize,
                            child: const Center(
                              child: Icon(
                                LucideIcons.smile,
                                size: AppIconSizes.defaultSize,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: canSend ? _handleSend : null,
                          child: Opacity(
                            opacity: canSend ? 1.0 : 0.5,
                            child: Container(
                              width: actionSize,
                              height: actionSize,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.send,
                                size: AppIconSizes.s,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(ChatAttachment file) {
    return AttachmentPill(
      file: file,
      onRetry: () => _retryAttachment(file),
      onRemove: () => _removeAttachment(file.id),
    );
  }
}
