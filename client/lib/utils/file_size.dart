String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(kilobytes >= 100 ? 0 : 1)} KB';
  }

  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(megabytes >= 100 ? 0 : 1)} MB';
}
