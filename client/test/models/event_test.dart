import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/models/event.dart';

void main() {
  group('Event', () {
    test('parses summary payloads without preview fields', () {
      final event = Event.fromJson({
        'id': 'event-1',
        'name': 'Street Lunch',
        'status': 'ACTIVE',
        'type': 'PUBLIC',
        'createdBy': 'user-1',
        'location': {
          'address': 'Main Square',
          'latitude': 21.1,
          'longitude': 79.1,
        },
        'timings': {
          'start': '2026-03-20T10:00:00.000Z',
          'end': '2026-03-20T11:00:00.000Z',
        },
      });

      expect(event.hasPreviewData, isFalse);
      expect(event.hasFullDetail, isFalse);
      expect(event.media, isNull);
      expect(event.tags, isNull);
      expect(event.stats, isNull);
    });

    test('merges preview data onto a summary event', () {
      final summary = Event.fromJson({
        'id': 'event-1',
        'name': 'Street Lunch',
        'status': 'ACTIVE',
        'type': 'PUBLIC',
        'createdBy': 'user-1',
        'location': {
          'address': 'Main Square',
          'latitude': 21.1,
          'longitude': 79.1,
        },
        'timings': {
          'start': '2026-03-20T10:00:00.000Z',
          'end': '2026-03-20T11:00:00.000Z',
        },
      });

      final preview = Event.fromJson({
        'id': 'event-1',
        'name': 'Street Lunch',
        'status': 'ACTIVE',
        'type': 'PUBLIC',
        'createdBy': 'user-1',
        'location': {
          'address': 'Main Square',
          'latitude': 21.1,
          'longitude': 79.1,
        },
        'timings': {
          'start': '2026-03-20T10:00:00.000Z',
          'end': '2026-03-20T11:00:00.000Z',
        },
        'media': [
          {'id': 'media-1', 'url': 'https://example.com/a.jpg', 'type': 'image'},
        ],
        'tags': [
          {'id': 'tag-1', 'name': 'vegan'},
        ],
        'stats': {
          'viewCount': 12,
          'ratingCount': 3,
          'ratingAverage': 4.7,
        },
      });

      final merged = summary.merge(preview);

      expect(merged.hasPreviewData, isTrue);
      expect(merged.media, hasLength(1));
      expect(merged.tags, hasLength(1));
      expect(merged.stats?.viewCount, 12);
    });

    test('previewImageUrl picks the first image and skips video media', () {
      Event withMedia(List<Map<String, dynamic>> media) => Event.fromJson({
        'id': 'event-1',
        'name': 'Street Lunch',
        'status': 'ACTIVE',
        'type': 'PUBLIC',
        'createdBy': 'user-1',
        'timings': {
          'startTime': '2026-08-22T10:00:00.000Z',
          'endTime': '2026-08-22T12:00:00.000Z',
        },
        'location': {'address': 'Somewhere', 'latitude': 1.0, 'longitude': 2.0},
        'media': media,
      });

      expect(
        withMedia([
          {'id': 'm1', 'type': 'video', 'url': 'https://cdn/clip.mp4'},
          {'id': 'm2', 'type': 'image', 'url': 'https://cdn/photo.jpg'},
        ]).previewImageUrl,
        'https://cdn/photo.jpg',
      );

      expect(
        withMedia([
          {'id': 'm1', 'type': 'video', 'url': 'https://cdn/clip.mp4'},
        ]).previewImageUrl,
        isNull,
      );

      expect(withMedia(const []).previewImageUrl, isNull);
    });
  });
}
