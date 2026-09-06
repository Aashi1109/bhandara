import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foody_mobile/features/profile/models/profile_overview.dart';
import 'package:foody_mobile/features/profile/models/user.dart';
import 'package:foody_mobile/features/profile/providers/profile_overview.dart';
import 'package:foody_mobile/shared/providers/user.dart';
import 'package:foody_mobile/features/profile/screens/profile.dart';
import 'package:foody_mobile/shared/theme/theme.dart';
import 'package:foody_mobile/shared/widgets/skeleton.dart';

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
            theme: AppTheme.buildTheme(lightPalette),
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
            theme: AppTheme.buildTheme(lightPalette),
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

  testWidgets('impact overview shows tooltips only for points with stats', (
    tester,
  ) async {
    const userId = 'user-1';
    final user = User(id: userId, email: 'viewer@example.com', name: 'Viewer');
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
              impactStats: {
                'totalViews': 36,
                'avgRating': 4.8,
                'events': [
                  {
                    'id': 'event-1',
                    'name': 'Spring Supper',
                    'startTime': '2026-04-08T18:00:00.000Z',
                    'viewCount': 24,
                    'ratingAverage': 4.8,
                    'ratingCount': 5,
                  },
                  {
                    'id': 'event-2',
                    'name': 'Quiet Brunch',
                    'startTime': '2026-04-09T18:00:00.000Z',
                    'viewCount': 0,
                    'ratingAverage': 0,
                    'ratingCount': 0,
                  },
                  {
                    'id': 'event-3',
                    'name': 'Rooftop Dinner',
                    'startTime': '2026-04-10T18:00:00.000Z',
                    'viewCount': 12,
                    'ratingAverage': 4.6,
                    'ratingCount': 3,
                  },
                ],
              },
            ),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.buildTheme(lightPalette), routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message != null &&
            widget.message!.contains('Spring Supper'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message != null &&
            widget.message!.contains('Rooftop Dinner'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message != null &&
            widget.message!.contains('Quiet Brunch'),
      ),
      findsNothing,
    );
  });
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
