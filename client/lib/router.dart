import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/splash.dart';
import 'screens/onboarding.dart';
import 'screens/auth.dart';
import 'screens/login.dart';
import 'screens/preferences.dart';
import 'screens/explore.dart';
import 'screens/search.dart';
import 'screens/event_detail.dart';
import 'screens/event_ratings.dart';
import 'screens/event_attendees.dart';
import 'screens/create_event.dart';
import 'screens/success.dart';
import 'screens/chat.dart';
import 'screens/thread.dart';
import 'screens/profile.dart';
import 'screens/settings.dart';
import 'screens/settings/profile_details.dart';
import 'screens/settings/location.dart';
import 'screens/settings/password.dart';
import 'screens/settings/email.dart';
import 'screens/settings/cuisines.dart';
import 'screens/settings/notifications.dart';
import 'screens/settings/data_privacy.dart';
import 'screens/settings/help_support.dart';
import 'screens/settings/about.dart';
import 'screens/updates.dart';
import 'screens/profile_setup.dart';
import 'screens/media_preview_screen.dart';
import 'screens/profile_badges.dart';
import 'screens/my_events.dart';
import 'widgets/media_preview.dart';
import 'models/event.dart';
import 'models/location_picker.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: SplashScreen.routePath,
  routes: [
    GoRoute(
      path: SplashScreen.routePath,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: OnboardingScreen.routePath,
      builder: (context, state) =>
          OnboardingScreen(onComplete: () => context.go(AuthScreen.routePath)),
    ),
    GoRoute(
      path: AuthScreen.routePath,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: LoginScreen.routePath,
      builder: (context, state) =>
          LoginScreen(extra: state.extra as Map<String, dynamic>?),
    ),
    GoRoute(
      path: ProfileSetupScreen.routePath,
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: PreferencesScreen.routePath,
      builder: (context, state) => const PreferencesScreen(),
    ),
    GoRoute(
      path: ExploreScreen.routePath,
      builder: (context, state) => const ExploreScreen(),
    ),
    GoRoute(
      path: SearchScreen.routePath,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: EventDetailScreen.routePath,
      builder: (context, state) {
        final extra = state.extra;
        return EventDetailScreen(
          id: state.pathParameters['id']!,
          initialEvent: extra is Event ? extra : null,
        );
      },
    ),
    GoRoute(
      path: EventRatingsScreen.routePath,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return EventRatingsScreen(
          eventId: state.pathParameters['id']!,
          eventName: extra['eventName'] as String? ?? 'Event',
          isOwner: extra['isOwner'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: EventAttendeesScreen.routePath,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return EventAttendeesScreen(
          eventName: extra['eventName'] as String? ?? 'Event',
          attendees: (extra['attendees'] as List<dynamic>? ?? const [])
              .whereType<EventUser>()
              .toList(),
        );
      },
    ),
    GoRoute(
      path: CreateEventScreen.routePath,
      builder: (context, state) => CreateEventScreen(
        initialEvent: state.extra is Event ? state.extra! as Event : null,
      ),
    ),
    GoRoute(
      path: SuccessScreen.routePath,
      builder: (context, state) => SuccessScreen(
        event: state.extra is Event ? state.extra! as Event : null,
      ),
    ),
    GoRoute(
      path: ChatScreen.routePath,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ChatScreen(
          id: state.pathParameters['id']!,
          eventId: extra?['eventId'] as String?,
        );
      },
    ),
    GoRoute(
      path: ThreadScreen.routePath,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ThreadScreen(
          id: state.pathParameters['id']!,
          threadId: extra?['threadId'] as String?,
          chatId: extra?['chatId'] as String?,
          eventId: extra?['eventId'] as String?,
          initialMessage: extra?['message'] as dynamic,
        );
      },
    ),
    GoRoute(
      path: ProfileScreen.routePath,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ProfileScreen(userId: extra?['userId'] as String?);
      },
    ),
    GoRoute(
      path: SettingsScreen.routePath,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: ProfileDetailsScreen.routePath,
      builder: (context, state) => const ProfileDetailsScreen(),
    ),
    GoRoute(
      path: LocationSettingsScreen.routePath,
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is LocationScreenArgs
            ? extra
            : const LocationScreenArgs();
        return LocationSettingsScreen(
          mode: args.mode,
          initialLocation: args.initialLocation,
          initialCameraLatitude: args.initialCameraLatitude,
          initialCameraLongitude: args.initialCameraLongitude,
          initialZoom: args.initialZoom,
        );
      },
    ),
    GoRoute(
      path: PasswordSettingsScreen.routePath,
      builder: (context, state) => const PasswordSettingsScreen(),
    ),
    GoRoute(
      path: EmailSettingsScreen.routePath,
      builder: (context, state) => const EmailSettingsScreen(),
    ),
    GoRoute(
      path: CuisineInterestsScreen.routePath,
      builder: (context, state) => const CuisineInterestsScreen(),
    ),
    GoRoute(
      path: NotificationsSettingsScreen.routePath,
      builder: (context, state) => const NotificationsSettingsScreen(),
    ),
    GoRoute(
      path: DataPrivacyScreen.routePath,
      builder: (context, state) => const DataPrivacyScreen(),
    ),
    GoRoute(
      path: HelpSupportScreen.routePath,
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: AboutAppScreen.routePath,
      builder: (context, state) => const AboutAppScreen(),
    ),
    GoRoute(
      path: MediaPreviewScreen.routePath,
      builder: (context, state) {
        final extra = state.extra;
        final items = extra is Map<String, dynamic>
            ? (extra['items'] as List<MediaItem>? ?? const [])
            : (extra as List<MediaItem>? ?? const []);
        final initialIndex = extra is Map<String, dynamic>
            ? (extra['initialIndex'] as int? ?? 0)
            : 0;
        return MediaPreviewScreen(items: items, initialIndex: initialIndex);
      },
    ),
    GoRoute(
      path: ProfileBadgesScreen.routePath,
      builder: (context, state) => const ProfileBadgesScreen(),
    ),
    GoRoute(
      path: MyEventsScreen.routePath,
      builder: (context, state) => const MyEventsScreen(),
    ),
    GoRoute(
      path: UpdatesScreen.routePath,
      builder: (context, state) => const UpdatesScreen(),
    ),
  ],
);
