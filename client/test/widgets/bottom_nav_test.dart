import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/explore/screens/explore_screen.dart';
import 'package:foody_mobile/shared/theme/theme.dart';
import 'package:foody_mobile/shared/widgets/bottom_nav.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('bottom nav caps its width at 500 pixels', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: ExploreScreen.routePath,
      routes: [
        GoRoute(
          path: ExploreScreen.routePath,
          builder: (context, state) =>
              const Scaffold(body: Stack(children: [AppBottomNav()])),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.buildTheme(lightPalette), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(AppBottomNav.surfaceKey)).width,
      AppBottomNav.maxWidth,
    );
  });

  testWidgets(
    'inactive nav icons remain centered when wrapped in badge stack',
    (tester) async {
      final router = GoRouter(
        initialLocation: ExploreScreen.routePath,
        routes: [
          GoRoute(
            path: ExploreScreen.routePath,
            builder: (context, state) =>
                const Scaffold(body: Stack(children: [AppBottomNav()])),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.buildTheme(lightPalette),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inactiveHeartStack = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.heart),
              matching: find.byType(Stack),
            )
            .first,
      );

      expect(inactiveHeartStack.alignment, Alignment.center);
    },
  );
}
