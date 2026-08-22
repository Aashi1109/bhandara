import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders every badge illustration as SVG', (tester) async {
    const assets = [
      'assets/images/badges/first_event_v2.svg',
      'assets/images/badges/conversation_starter_v2.svg',
      'assets/images/badges/community_supporter_v2.svg',
      'assets/images/badges/week_streak_v2.svg',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final asset in assets)
                SvgPicture.asset(asset, width: 64, height: 64),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(assets.length));
  });
}
