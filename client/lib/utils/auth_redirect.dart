import '../models/user.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/preferences.dart';

String routeForAuthenticatedUser(User user) {
  return user.meta?.hasOnboarded ?? false
      ? ExploreScreen.routePath
      : PreferencesScreen.routePath;
}
