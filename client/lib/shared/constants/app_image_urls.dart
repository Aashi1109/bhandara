import '../../config.dart';

class AppImageUrls {
  AppImageUrls._();

  static String resolve(String path, {String? baseUrl}) {
    final normalizedBase = (baseUrl ?? AppConfig.cloudinaryImageBaseUrl)
        .replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    return '$normalizedBase/$normalizedPath';
  }

  static const String peopleParty =
      'https://res.cloudinary.com/aashish1109/image/upload/v1787339396/Zentry/platform/graphics/people-party.svg';

  static const String eventAttendees =
      'https://res.cloudinary.com/aashish1109/image/upload/v1787339395/Zentry/platform/graphics/event-attendees_k6c2v2.svg';

  static const String womenWritingLetter =
      'https://res.cloudinary.com/aashish1109/image/upload/v1787339394/Zentry/platform/graphics/women-writing-letter.svg';

  static const String emptyGuestList =
      'assets/images/event-empty-states/guest-list.svg';

  static const String manageEventsOverview = peopleParty;
  static const String emptyUpcomingEvents = eventAttendees;
  static const String emptyPastEvents = peopleParty;
  static const String emptyDraftEvents = womenWritingLetter;
  static const String emptyEventAttendees = emptyGuestList;
  static const String emptyAttendeeSearch = emptyGuestList;
}
