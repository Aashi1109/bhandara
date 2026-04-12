import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foody_mobile/models/profile_overview.dart';
import 'package:foody_mobile/models/user.dart';
import 'package:foody_mobile/providers/profile_overview.dart';
import 'package:foody_mobile/providers/user.dart';
import 'package:foody_mobile/screens/profile.dart';
import 'package:foody_mobile/theme/theme.dart';
import 'package:foody_mobile/widgets/skeleton.dart';

void main() {
  testWidgets(
    'profile badges show skeletons while overview is loading instead of empty copy',
    (tester) async {
      const userId = 'user-1';
      final router = GoRouter(
        initialLocation: ProfileScreen.routePath,
        routes: [
          GoRoute(
            path: ProfileScreen.routePath,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _StaticUserProfile()),
            profileOverviewProvider(
              userId: userId,
            ).overrideWith((ref) => Completer<ProfileOverview>().future),
          ],
          child: MaterialApp.router(
            theme: AppTheme.theme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No badges unlocked yet.'), findsNothing);
      expect(find.byType(AppSkeleton), findsWidgets);
    },
  );

  testWidgets(
    'own profile recovers from empty cached user state by loading the current user',
    (tester) async {
      const userId = 'user-1';
      final user = User(
        id: userId,
        email: 'viewer@example.com',
        name: 'Viewer',
      );
      final router = GoRouter(
        initialLocation: ProfileScreen.routePath,
        routes: [
          GoRoute(
            path: ProfileScreen.routePath,
            builder: (context, state) =>
                ProfileScreen(currentUserLoader: () async => user),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _NullUserProfile()),
            profileOverviewProvider(userId: userId).overrideWith(
              (ref) async => ProfileOverview(
                myEvents: const [],
                achievements: const [],
                recentActivity: const [],
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.theme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('User not found'), findsNothing);
      expect(find.text('Viewer'), findsOneWidget);
    },
  );
}

class _StaticUserProfile extends UserProfile {
  @override
  FutureOr<User?> build() async =>
      User(id: 'user-1', email: 'viewer@example.com', name: 'Viewer');
}

class _NullUserProfile extends UserProfile {
  @override
  FutureOr<User?> build() => null;
}
