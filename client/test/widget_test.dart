import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FoodyApp()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(FoodyApp), findsOneWidget);
  });
}
