import '../../features/profile/models/user.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/onboarding/screens/preferences.dart';

String routeForAuthenticatedUser(User user) {
  return user.meta?.hasOnboarded ?? false
      ? ExploreScreen.routePath
      : PreferencesScreen.routePath;
}
