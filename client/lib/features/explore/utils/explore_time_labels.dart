String formatExploreRelativeTime(
  DateTime startTime,
  DateTime endTime, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();

  if (currentTime.isAfter(endTime)) {
    return 'Ended';
  }

  if (currentTime.isBefore(startTime)) {
    return 'Starts in ${_formatDuration(startTime.difference(currentTime))}';
  }

  return 'Ends in ${_formatDuration(endTime.difference(currentTime))}';
}

String _formatDuration(Duration duration) {
  if (duration.inDays >= 2) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    if (hours > 0) {
      return '$days day${days == 1 ? '' : 's'} $hours hr';
    }
    return '$days day${days == 1 ? '' : 's'}';
  }

  if (duration.inDays == 1) {
    final hours = duration.inHours.remainder(24);
    if (hours > 0) {
      return '1 day $hours hr';
    }
    return '1 day';
  }

  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    if (minutes > 0) {
      return '$hours hr $minutes min';
    }
    return '$hours hr';
  }

  final clampedMinutes = duration.inMinutes < 1 ? 1 : duration.inMinutes;
  return '$clampedMinutes min';
}
