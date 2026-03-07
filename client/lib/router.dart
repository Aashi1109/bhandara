import 'package:go_router/go_router.dart';

import 'screens/splash.dart';
import 'screens/onboarding.dart';
import 'screens/auth.dart';
import 'screens/login.dart';
import 'screens/preferences.dart';
import 'screens/explore.dart';
import 'screens/search.dart';
import 'screens/event_detail.dart';
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
import 'screens/updates.dart';

final router = GoRouter(
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
      builder: (context, state) {
        final email =
            state.uri.queryParameters['email'] ?? 'john.doe@example.com';
        return LoginScreen(email: email);
      },
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
      builder: (context, state) =>
          EventDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: CreateEventScreen.routePath,
      builder: (context, state) => const CreateEventScreen(),
    ),
    GoRoute(
      path: SuccessScreen.routePath,
      builder: (context, state) => const SuccessScreen(),
    ),
    GoRoute(
      path: ChatScreen.routePath,
      builder: (context, state) => ChatScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: ThreadScreen.routePath,
      builder: (context, state) =>
          ThreadScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: ProfileScreen.routePath,
      builder: (context, state) => const ProfileScreen(),
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
      builder: (context, state) => const LocationSettingsScreen(),
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
      path: UpdatesScreen.routePath,
      builder: (context, state) => const UpdatesScreen(),
    ),
  ],
);
