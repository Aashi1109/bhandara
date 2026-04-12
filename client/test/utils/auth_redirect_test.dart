import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/profile/models/user.dart';
import 'package:foody_mobile/features/explore/screens/explore_screen.dart';
import 'package:foody_mobile/features/onboarding/screens/preferences.dart';
import 'package:foody_mobile/shared/utils/auth_redirect.dart';

void main() {
  group('routeForAuthenticatedUser', () {
    test('routes onboarded users to explore', () {
      final user = User(
        id: 'user-1',
        email: 'onboarded@example.com',
        meta: UserMeta(hasOnboarded: true),
      );

      expect(routeForAuthenticatedUser(user), ExploreScreen.routePath);
    });

    test('routes non-onboarded users to preferences', () {
      final user = User(
        id: 'user-2',
        email: 'new@example.com',
        meta: UserMeta(hasOnboarded: false),
      );

      expect(routeForAuthenticatedUser(user), PreferencesScreen.routePath);
    });

    test('defaults missing meta to preferences', () {
      final user = User(id: 'user-3', email: 'missing-meta@example.com');

      expect(routeForAuthenticatedUser(user), PreferencesScreen.routePath);
    });
  });
}
