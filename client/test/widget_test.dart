import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/main.dart';
import 'package:foody_mobile/shared/providers/theme_preference.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePreferenceProvider.overrideWith(_TestThemePreference.new),
        ],
        child: const FoodyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(FoodyApp), findsOneWidget);
  });
}

class _TestThemePreference extends ThemePreference {
  @override
  Future<String> build() async => 'system';
}
