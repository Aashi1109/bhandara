import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/theme.dart';
import '../services/file.dart';

class ChatAttachment {
  final String id;
  final String? mediaId; // Null if still uploading
  final String name;
  final String? url; // Public URL if uploaded
  final String localPath;
  final bool isVideo;
  final bool isUploading;

  ChatAttachment({
    required this.id,
    this.mediaId,
    required this.name,
    this.url,
    required this.localPath,
    this.isVideo = false,
    this.isUploading = false,
  });

  ChatAttachment copyWith({String? mediaId, String? url, bool? isUploading}) {
    return ChatAttachment(
      id: id,
      mediaId: mediaId ?? this.mediaId,
      name: name,
      url: url ?? this.url,
      localPath: localPath,
      isVideo: isVideo,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class FloatingMessageBar extends StatefulWidget {
  final String placeholder;
  final Function(String message, List<String> mediaIds) onSend;
  final bool isVisible;

  const FloatingMessageBar({
    super.key,
    this.placeholder = 'Add a reply...',
    required this.onSend,
    this.isVisible = true,
  });

  @override
  State<FloatingMessageBar> createState() => _FloatingMessageBarState();
}

class _FloatingMessageBarState extends State<FloatingMessageBar> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatAttachment> _attachments = [];

  void _handleSend() {
    final allUploaded = _attachments.every(
      (a) => a.mediaId != null && !a.isUploading,
    );
    if (!allUploaded) return;

    if (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty) {
      final mediaIds = _attachments.map((a) => a.mediaId!).toList();
      widget.onSend(_controller.text, mediaIds);
      _controller.clear();
      setState(() {
        _attachments.clear();
      });
    }
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
        isVideo: isVideo,
        isUploading: true,
      );

      setState(() {
        _attachments.add(attachment);
      });

      // Start upload in background
      final mediaId = await fileService.uploadFile(file);

      if (mounted) {
        setState(() {
          final index = _attachments.indexWhere((a) => a.id == attachment.id);
          if (index != -1) {
            if (mediaId != null) {
              _attachments[index] = _attachments[index].copyWith(
                mediaId: mediaId,
                isUploading: false,
              );
            } else {
              _attachments.removeAt(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to upload file')),
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((a) => a.id == id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
        _attachments.every((a) => !a.isUploading);

    return AnimatedSlide(
      offset: widget.isVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.of(context).padding.bottom + 16,
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

              // Message Bar Pill
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    PopupMenuButton<bool>(
                      onSelected: _pickMedia,
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.muted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.plus,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      offset: const Offset(0, -100),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: false,
                          child: ListTile(
                            leading: Icon(LucideIcons.image, size: 20),
                            title: Text('Image'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const PopupMenuItem(
                          value: true,
                          child: ListTile(
                            leading: Icon(LucideIcons.video, size: 20),
                            title: Text('Video (Max 10MB)'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.smile,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: canSend ? _handleSend : null,
                      child: Opacity(
                        opacity: canSend ? 1.0 : 0.5,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.send,
                            size: 14,
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
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(ChatAttachment file) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  file.isVideo ? LucideIcons.video : LucideIcons.image,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
                if (file.isUploading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              file.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _removeAttachment(file.id),
            child: const Icon(
              LucideIcons.x,
              size: 14,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
