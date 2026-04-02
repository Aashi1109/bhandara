import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/models/event.dart';
import 'package:foody_mobile/screens/explore/utils/explore_event_cards.dart';

void main() {
  group('findExploreEventIndex', () {
    test('returns -1 when there is no explicit selection', () {
      expect(findExploreEventIndex(_events(), null), -1);
    });

    test('returns matching index when event exists', () {
      expect(findExploreEventIndex(_events(), 'event_2'), 1);
    });
  });

  group('reconcileSelectedExploreEvent', () {
    test('does not auto-select the first event when selection is null', () {
      expect(reconcileSelectedExploreEvent(_events(), null), isNull);
    });

    test('preserves selection only while event remains visible', () {
      final selectedEvent = _event(
        id: 'event_2',
        stats: EventStats(
          reactionCount: 0,
          threadCount: 0,
          participantCount: 0,
          verifierCount: 0,
          mediaCount: 0,
          tagCount: 0,
          viewCount: 42,
          ratingCount: 3,
          ratingAverage: 4.5,
        ),
      );

      expect(
        reconcileSelectedExploreEvent(
          _events(),
          selectedEvent,
        )?.stats?.viewCount,
        42,
      );
      expect(
        reconcileSelectedExploreEvent(
          _events().where((event) => event.id != 'event_2').toList(),
          selectedEvent,
        ),
        isNull,
      );
    });
  });

  group('buildExploreEventCardIndicatorWindow', () {
    test('uses exact dot count when there are three or fewer cards', () {
      final window = buildExploreEventCardIndicatorWindow(
        itemCount: 2,
        currentIndex: 1,
      );

      expect(window.pageIndices, [0, 1]);
      expect(window.activeDotIndex, 1);
    });

    test('keeps a compact three-dot window and shifts through the list', () {
      final leadingWindow = buildExploreEventCardIndicatorWindow(
        itemCount: 5,
        currentIndex: 0,
      );
      final centeredWindow = buildExploreEventCardIndicatorWindow(
        itemCount: 5,
        currentIndex: 2,
      );
      final trailingWindow = buildExploreEventCardIndicatorWindow(
        itemCount: 5,
        currentIndex: 4,
      );

      expect(leadingWindow.pageIndices, [0, 1, 2]);
      expect(leadingWindow.activeDotIndex, 0);

      expect(centeredWindow.pageIndices, [1, 2, 3]);
      expect(centeredWindow.activeDotIndex, 1);

      expect(trailingWindow.pageIndices, [2, 3, 4]);
      expect(trailingWindow.activeDotIndex, 2);
    });
  });
}

List<Event> _events() => <Event>[
  _event(id: 'event_1'),
  _event(id: 'event_2'),
  _event(id: 'event_3'),
];

Event _event({required String id, EventStats? stats}) {
  final startTime = DateTime(2026, 3, 27, 18);
  return Event(
    id: id,
    name: 'Event $id',
    status: 'UPCOMING',
    type: 'organized',
    startTime: startTime,
    endTime: startTime.add(const Duration(hours: 2)),
    createdBy: 'user_1',
    location: Location(
      address: 'Nagpur',
      latitude: 21.1458,
      longitude: 79.0882,
    ),
    stats: stats,
  );
}
