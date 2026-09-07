DateTime roundDateTimeToQuarterHour(DateTime value) {
  final remainder = value.minute % 15;
  final next = remainder == 0 ? value : value.add(Duration(minutes: 15 - remainder));
  return DateTime(next.year, next.month, next.day, next.hour, next.minute);
}

DateTime normalizeEventEndDateTime({
  required DateTime start,
  required DateTime proposedEnd,
  Duration minGap = const Duration(minutes: 30),
  Duration maxRange = const Duration(days: 7),
}) {
  var normalized = proposedEnd;
  if (!normalized.isAfter(start)) {
    normalized = start.add(minGap);
  }

  final maxEnd = start.add(maxRange);
  if (normalized.isAfter(maxEnd)) {
    normalized = maxEnd;
  }

  return normalized;
}
