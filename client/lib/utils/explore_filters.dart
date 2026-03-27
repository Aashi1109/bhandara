import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/event.dart';
import 'event_status.dart';

const Object _exploreFilterUnset = Object();

class ExploreDatePresetValues {
  static const String anytime = 'anytime';
  static const String today = 'today';
  static const String thisWeek = 'this_week';
  static const String thisMonth = 'this_month';
}

class ExploreEventTypeValues {
  static const String organized = 'organized';
  static const String custom = 'custom';
}

class ExploreFilterState {
  const ExploreFilterState({
    this.quickStatus = EventStatusValue.all,
    this.radiusKm = 5,
    this.tagIds = const <String>{},
    this.eventType,
    this.datePreset = ExploreDatePresetValues.anytime,
  });

  final String quickStatus;
  final double radiusKm;
  final Set<String> tagIds;
  final String? eventType;
  final String datePreset;

  ExploreFilterState copyWith({
    String? quickStatus,
    double? radiusKm,
    Set<String>? tagIds,
    Object? eventType = _exploreFilterUnset,
    String? datePreset,
  }) {
    return ExploreFilterState(
      quickStatus: quickStatus ?? this.quickStatus,
      radiusKm: radiusKm ?? this.radiusKm,
      tagIds: tagIds ?? this.tagIds,
      eventType: identical(eventType, _exploreFilterUnset)
          ? this.eventType
          : eventType as String?,
      datePreset: datePreset ?? this.datePreset,
    );
  }
}

bool matchesExploreFilters(
  Event event, {
  required ExploreFilterState filters,
  required LatLng? effectiveLocation,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final status = resolveEventStatus(event, now: resolvedNow);
  final matchesQuickStatus =
      filters.quickStatus == EventStatusValue.all ||
      status == filters.quickStatus;
  if (!matchesQuickStatus) {
    return false;
  }

  if (filters.eventType != null && event.type != filters.eventType) {
    return false;
  }

  final dateRange = resolveExploreDatePresetRange(
    filters.datePreset,
    resolvedNow,
  );
  if (dateRange != null &&
      (event.startTime.isBefore(dateRange.$1) ||
          event.startTime.isAfter(dateRange.$2))) {
    return false;
  }

  if (filters.tagIds.isNotEmpty) {
    final eventTagIds =
        event.tags?.map((tag) => tag.id).where((id) => id.isNotEmpty).toSet() ??
        const <String>{};
    if (!eventTagIds.any(filters.tagIds.contains)) {
      return false;
    }
  }

  if (effectiveLocation == null) {
    return true;
  }

  final radiusMeters = filters.radiusKm * 1000;
  final matchesRadius = (() {
    final lat = event.location.latitude;
    final lng = event.location.longitude;
    if (lat == null || lng == null) {
      return false;
    }

    return _distanceInMeters(
          effectiveLocation.latitude,
          effectiveLocation.longitude,
          lat,
          lng,
        ) <=
        radiusMeters;
  })();

  return matchesRadius;
}

List<Event> filterExploreEvents(
  List<Event> events, {
  required ExploreFilterState filters,
  required LatLng? effectiveLocation,
  DateTime? now,
}) {
  return events
      .where(
        (event) => matchesExploreFilters(
          event,
          filters: filters,
          effectiveLocation: effectiveLocation,
          now: now,
        ),
      )
      .toList();
}

(DateTime, DateTime)? resolveExploreDatePresetRange(
  String datePreset,
  DateTime now,
) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  switch (datePreset) {
    case ExploreDatePresetValues.today:
      return (
        startOfToday,
        startOfToday.add(const Duration(days: 1)).subtract(
          const Duration(milliseconds: 1),
        ),
      );
    case ExploreDatePresetValues.thisWeek:
      final weekStart = startOfToday.subtract(
        Duration(days: now.weekday - DateTime.monday),
      );
      final weekEnd = weekStart.add(const Duration(days: 7)).subtract(
        const Duration(milliseconds: 1),
      );
      return (weekStart, weekEnd);
    case ExploreDatePresetValues.thisMonth:
      final monthStart = DateTime(now.year, now.month);
      final nextMonth = now.month == DateTime.december
          ? DateTime(now.year + 1, DateTime.january)
          : DateTime(now.year, now.month + 1);
      return (
        monthStart,
        nextMonth.subtract(const Duration(milliseconds: 1)),
      );
    case ExploreDatePresetValues.anytime:
    default:
      return null;
  }
}

double _distanceInMeters(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(endLat - startLat);
  final dLng = _toRadians(endLng - startLng);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(startLat)) *
          cos(_toRadians(endLat)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double value) => value * pi / 180;
