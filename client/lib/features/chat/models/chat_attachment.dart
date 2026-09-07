class ChatAttachment {
  ChatAttachment({
    required this.id,
    this.mediaId,
    required this.name,
    this.url,
    required this.localPath,
    required this.sizeBytes,
    this.isVideo = false,
    this.isUploading = false,
    this.hasFailed = false,
  });

  final String id;
  final String? mediaId;
  final String name;
  final String? url;
  final String localPath;
  final int sizeBytes;
  final bool isVideo;
  final bool isUploading;
  final bool hasFailed;

  ChatAttachment copyWith({
    String? mediaId,
    String? url,
    bool? isUploading,
    bool? hasFailed,
  }) {
    return ChatAttachment(
      id: id,
      mediaId: mediaId ?? this.mediaId,
      name: name,
      url: url ?? this.url,
      localPath: localPath,
      sizeBytes: sizeBytes,
      isVideo: isVideo,
      isUploading: isUploading ?? this.isUploading,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }
}
