import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/theme/theme.dart';
import 'package:foody_mobile/widgets/button.dart';

void main() {
  testWidgets('disabled button has no tap handler and muted label color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(
          body: Center(child: AppButton(label: 'Save')),
        ),
      ),
    );

    final gestureDetector = tester.widget<GestureDetector>(
      find.byType(GestureDetector),
    );
    final label = tester.widget<Text>(find.text('Save'));

    expect(gestureDetector.onTap, isNull);
    expect(label.style?.color, AppColors.mutedForeground);
  });

  testWidgets('enabled button invokes callback once when tapped', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Center(
            child: AppButton(
              label: 'Save',
              onPressed: () {
                taps += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets(
    'icon-only button uses compact padding so the icon stays visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 64,
                child: AppButton(
                  size: AppButtonSize.lg,
                  icon: Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(
        container.padding,
        const EdgeInsets.symmetric(
          horizontal: (56 - AppIconSizes.defaultSize) / 2,
        ),
      );
    },
  );
}
