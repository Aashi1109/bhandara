import '../models/event.dart';

class EventStatusValue {
  static const all = 'all';
  static const upcoming = 'upcoming';
  static const ongoing = 'ongoing';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

String deriveEventStatus({
  required DateTime startTime,
  required DateTime endTime,
  String? currentStatus,
  DateTime? now,
}) {
  final normalizedStatus = currentStatus?.toLowerCase();
  if (normalizedStatus == EventStatusValue.cancelled) {
    return EventStatusValue.cancelled;
  }

  final currentTime = now ?? DateTime.now();
  if (!currentTime.isBefore(endTime)) {
    return EventStatusValue.completed;
  }
  if (!currentTime.isBefore(startTime)) {
    return EventStatusValue.ongoing;
  }
  return EventStatusValue.upcoming;
}

String resolveEventStatus(Event event, {DateTime? now}) {
  return deriveEventStatus(
    startTime: event.startTime,
    endTime: event.endTime,
    currentStatus: event.status,
    now: now,
  );
}

String formatEventStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case EventStatusValue.ongoing:
      return 'Ongoing';
    case EventStatusValue.completed:
      return 'Completed';
    case EventStatusValue.cancelled:
      return 'Cancelled';
    case EventStatusValue.upcoming:
    default:
      return 'Upcoming';
  }
}

bool isDiscoverableEventStatus(String status) =>
    status == EventStatusValue.ongoing || status == EventStatusValue.upcoming;
