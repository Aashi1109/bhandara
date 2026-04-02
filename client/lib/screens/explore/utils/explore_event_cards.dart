import '../../../models/event.dart';

int findExploreEventIndex(List<Event> events, String? eventId) {
  if (eventId == null) {
    return -1;
  }

  for (var index = 0; index < events.length; index++) {
    if (events[index].id == eventId) {
      return index;
    }
  }

  return -1;
}

Event? reconcileSelectedExploreEvent(List<Event> events, Event? selectedEvent) {
  if (selectedEvent == null) {
    return null;
  }

  final selectedIndex = findExploreEventIndex(events, selectedEvent.id);
  if (selectedIndex == -1) {
    return null;
  }

  return selectedEvent.merge(events[selectedIndex]);
}

class ExploreEventCardIndicatorWindow {
  const ExploreEventCardIndicatorWindow({
    required this.startIndex,
    required this.visibleDotCount,
    required this.activeDotIndex,
  });

  final int startIndex;
  final int visibleDotCount;
  final int activeDotIndex;

  List<int> get pageIndices =>
      List<int>.generate(visibleDotCount, (index) => startIndex + index);
}

ExploreEventCardIndicatorWindow buildExploreEventCardIndicatorWindow({
  required int itemCount,
  required int currentIndex,
  int maxVisibleDots = 3,
}) {
  assert(itemCount > 0, 'itemCount must be positive.');
  assert(maxVisibleDots > 0, 'maxVisibleDots must be positive.');

  final clampedCurrentIndex = currentIndex.clamp(0, itemCount - 1);
  final visibleDotCount = itemCount < maxVisibleDots
      ? itemCount
      : maxVisibleDots;

  if (itemCount <= maxVisibleDots) {
    return ExploreEventCardIndicatorWindow(
      startIndex: 0,
      visibleDotCount: visibleDotCount,
      activeDotIndex: clampedCurrentIndex,
    );
  }

  final startIndex = (clampedCurrentIndex - 1).clamp(
    0,
    itemCount - visibleDotCount,
  );

  return ExploreEventCardIndicatorWindow(
    startIndex: startIndex,
    visibleDotCount: visibleDotCount,
    activeDotIndex: clampedCurrentIndex - startIndex,
  );
}
