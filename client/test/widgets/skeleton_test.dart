import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/theme/theme.dart';
import 'package:foody_mobile/widgets/skeleton.dart';

void main() {
  testWidgets('renders rectangular and circular skeleton variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(
          body: Column(
            children: [
              AppSkeleton(width: 120, height: 24),
              SizedBox(height: 12),
              AppSkeleton(width: 40, height: 40, shape: BoxShape.circle),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppSkeleton), findsNWidgets(2));
    expect(find.byType(ClipRRect), findsNWidgets(2));
  });

  testWidgets('app skeleton line respects explicit sizing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(body: AppSkeletonLine(width: 180, height: 14)),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(AppSkeletonLine),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 180 && widget.height == 14,
        ),
      ),
    );

    expect(sizedBox.width, 180);
    expect(sizedBox.height, 14);
  });

  testWidgets('shimmer animation pumps without exceptions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(body: AppSkeleton(width: 160, height: 16)),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
