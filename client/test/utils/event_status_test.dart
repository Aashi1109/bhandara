import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/models/event.dart';
import 'package:foody_mobile/utils/event_status.dart';
import 'package:foody_mobile/screens/explore/utils/explore_filters.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('deriveEventStatus resolves ongoing and completed from timings', () {
    final now = DateTime(2026, 3, 21, 12);

    expect(
      deriveEventStatus(
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 1)),
        currentStatus: 'draft',
        now: now,
      ),
      EventStatusValue.ongoing,
    );

    expect(
      deriveEventStatus(
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.subtract(const Duration(minutes: 1)),
        currentStatus: 'upcoming',
        now: now,
      ),
      EventStatusValue.completed,
    );
  });

  test('cancelled status is preserved over timing-derived values', () {
    final now = DateTime(2026, 3, 21, 12);

    expect(
      deriveEventStatus(
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        currentStatus: 'cancelled',
        now: now,
      ),
      EventStatusValue.cancelled,
    );
  });

  test('filterExploreEvents combines status radius and category filters', () {
    final now = DateTime(2026, 3, 21, 12);
    final events = [
      Event(
        id: 'ongoing-nearby',
        name: 'Nearby Ongoing',
        status: 'draft',
        type: 'custom',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 1)),
        createdBy: 'user-1',
        location: Location(
          address: 'Nearby',
          latitude: 21.1458,
          longitude: 79.0882,
        ),
        tags: [Tag(id: 'tag-1', name: 'Bakery')],
      ),
      Event(
        id: 'ongoing-far',
        name: 'Far Ongoing',
        status: 'ongoing',
        type: 'custom',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 1)),
        createdBy: 'user-1',
        location: Location(
          address: 'Far',
          latitude: 21.4458,
          longitude: 79.3882,
        ),
        tags: [Tag(id: 'tag-1', name: 'Bakery')],
      ),
      Event(
        id: 'upcoming-nearby',
        name: 'Nearby Upcoming',
        status: 'upcoming',
        type: 'custom',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 4)),
        createdBy: 'user-1',
        location: Location(
          address: 'Nearby Upcoming',
          latitude: 21.146,
          longitude: 79.0884,
        ),
        tags: [Tag(id: 'tag-2', name: 'Street Food')],
      ),
    ];

    final results = filterExploreEvents(
      events,
      filters: const ExploreFilterState(
        quickStatus: EventStatusValue.ongoing,
        radiusKm: 5,
        tagIds: {'tag-1'},
      ),
      effectiveLocation: const LatLng(21.1458, 79.0882),
      now: now,
    );

    expect(results.map((event) => event.id), ['ongoing-nearby']);
  });
}
