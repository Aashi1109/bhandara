import 'package:go_router/go_router.dart';
import './globals.dart';

import './features/auth/screens/splash.dart';
import './features/onboarding/screens/onboarding.dart';
import './features/auth/screens/auth.dart';
import './features/auth/screens/login.dart';
import './features/onboarding/screens/preferences.dart';
import './features/explore/screens/explore_screen.dart';
import './features/search/screens/search.dart';
import './features/saved/screens/saved.dart';
import './features/events/screens/event_detail.dart';
import './features/events/screens/event_ratings.dart';
import './features/events/screens/event_attendees.dart';
import './features/events/screens/create_event.dart';
import './features/auth/screens/success.dart';
import './features/auth/screens/forgot_password.dart';
import './features/auth/screens/forgot_password_otp.dart';
import './features/auth/screens/reset_password.dart';
import './features/chat/screens/chat.dart';
import './features/chat/screens/thread.dart';
import './features/profile/screens/profile.dart';
import './features/settings/screens/settings.dart';
import './features/settings/screens/profile_details.dart';
import './features/settings/screens/location.dart';
import './features/settings/screens/password.dart';
import './features/settings/screens/email.dart';
import './features/settings/screens/cuisines.dart';
import './features/settings/screens/notifications.dart';
import './features/settings/screens/data_privacy.dart';
import './features/settings/screens/help_support.dart';
import './features/settings/screens/about.dart';
import './features/updates/screens/updates.dart';
import './features/onboarding/screens/profile_setup.dart';
import './features/profile/screens/profile_badges.dart';
import './features/events/screens/my_events.dart';
import './features/events/models/event.dart';
import './shared/models/location_picker.dart';

Map<String, dynamic>? _extraAsMap(Object? extra) =>
    extra is Map<String, dynamic> ? extra : null;

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
      builder: (context, state) => LoginScreen(extra: _extraAsMap(state.extra)),
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
      path: SavedScreen.routePath,
      builder: (context, state) => const SavedScreen(),
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
        final extra = _extraAsMap(state.extra) ?? const <String, dynamic>{};
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
        final extra = _extraAsMap(state.extra) ?? const <String, dynamic>{};
        return EventAttendeesScreen(
          eventName: extra['eventName'] as String? ?? 'Event',
          attendees: (extra['attendees'] as List<dynamic>? ?? const [])
              .whereType<EventUser>()
              .toList(),
          capacity: extra['capacity'] as int?,
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
      path: ForgotPasswordScreen.routePath,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: ForgotPasswordOTPScreen.routePath,
      builder: (context, state) {
        final extra = _extraAsMap(state.extra);
        return ForgotPasswordOTPScreen(
          email: extra?['email'] as String?,
        );
      },
    ),
    GoRoute(
      path: ResetPasswordScreen.routePath,
      builder: (context, state) {
        final extra = _extraAsMap(state.extra);
        return ResetPasswordScreen(
          token: extra?['token'] as String?,
          email: extra?['email'] as String?,
        );
      },
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
        final extra = _extraAsMap(state.extra);
        return ChatScreen(
          id: state.pathParameters['id'],
          eventId: extra?['eventId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/event/:id/discussion',
      builder: (context, state) => ChatScreen(
        eventId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: ThreadScreen.routePath,
      builder: (context, state) {
        final extra = _extraAsMap(state.extra);
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
        final extra = _extraAsMap(state.extra);
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
