import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/constants/app_image_urls.dart';

void main() {
  test('builds Cloudinary image URLs from one shared base path', () {
    expect(
      AppImageUrls.resolve(
        '/events/empty-states/upcoming-events.svg',
        baseUrl: 'https://res.cloudinary.com/demo/image/upload/zentry/mobile/',
      ),
      'https://res.cloudinary.com/demo/image/upload/zentry/mobile/events/empty-states/upcoming-events.svg',
    );
  });

  test('keeps supplied Cloudinary illustration URLs in one constants class', () {
    expect(
      AppImageUrls.peopleParty,
      'https://res.cloudinary.com/aashish1109/image/upload/v1787339396/Zentry/platform/graphics/people-party.svg',
    );
    expect(
      AppImageUrls.eventAttendees,
      'https://res.cloudinary.com/aashish1109/image/upload/v1787339395/Zentry/platform/graphics/event-attendees_k6c2v2.svg',
    );
    expect(
      AppImageUrls.womenWritingLetter,
      'https://res.cloudinary.com/aashish1109/image/upload/v1787339394/Zentry/platform/graphics/women-writing-letter.svg',
    );
  });

  test('maps each event illustration to the appropriate supplied asset', () {
    expect(AppImageUrls.manageEventsOverview, AppImageUrls.peopleParty);
    expect(AppImageUrls.emptyUpcomingEvents, AppImageUrls.eventAttendees);
    expect(AppImageUrls.emptyPastEvents, AppImageUrls.peopleParty);
    expect(AppImageUrls.emptyDraftEvents, AppImageUrls.womenWritingLetter);
    expect(AppImageUrls.emptyEventAttendees, AppImageUrls.emptyGuestList);
    expect(AppImageUrls.emptyAttendeeSearch, AppImageUrls.emptyGuestList);
  });
}
