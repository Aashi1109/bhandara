import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/event.dart';
import 'event_status.dart';

class ExploreFilterState {
  const ExploreFilterState({
    this.quickStatus = EventStatusValue.all,
    this.radiusKm = 5,
    this.tagIds = const <String>{},
  });

  final String quickStatus;
  final double radiusKm;
  final Set<String> tagIds;

  ExploreFilterState copyWith({
    String? quickStatus,
    double? radiusKm,
    Set<String>? tagIds,
  }) {
    return ExploreFilterState(
      quickStatus: quickStatus ?? this.quickStatus,
      radiusKm: radiusKm ?? this.radiusKm,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}

List<Event> filterExploreEvents(
  List<Event> events, {
  required ExploreFilterState filters,
  required LatLng? effectiveLocation,
  DateTime? now,
}) {
  final byStatusAndTags = events.where((event) {
    final status = resolveEventStatus(event, now: now);
    final matchesQuickStatus =
        filters.quickStatus == EventStatusValue.all ||
        status == filters.quickStatus;
    if (!matchesQuickStatus) {
      return false;
    }

    if (filters.tagIds.isEmpty) {
      return true;
    }

    final eventTagIds =
        event.tags?.map((tag) => tag.id).where((id) => id.isNotEmpty).toSet() ??
        const <String>{};
    return eventTagIds.any(filters.tagIds.contains);
  }).toList();

  if (effectiveLocation == null) {
    return byStatusAndTags;
  }

  final radiusMeters = filters.radiusKm * 1000;
  return byStatusAndTags.where((event) {
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
  }).toList();
}

List<Event> filterExploreEventsWithoutRadius(
  List<Event> events, {
  required ExploreFilterState filters,
  DateTime? now,
}) {
  return filterExploreEvents(
    events,
    filters: filters.copyWith(radiusKm: double.infinity),
    effectiveLocation: null,
    now: now,
  );
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
