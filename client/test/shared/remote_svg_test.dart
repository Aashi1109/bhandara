import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/widgets/remote_svg.dart';

void main() {
  test('recognizes local SVG assets', () {
    expect(
      AppRemoteSvg.isSvgSource(
        'assets/images/event-empty-states/guest-list.svg',
      ),
      isTrue,
    );
    expect(AppRemoteSvg.isSvgSource('assets/images/guest-list.png'), isFalse);
  });

  testWidgets('renders the local guest-list SVG as vector artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppRemoteSvg(
            url: 'assets/images/event-empty-states/guest-list.svg',
            width: 210,
            height: 154,
            semanticsLabel: 'Guest list illustration',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('uses Cloudinary rasterization for nested network SVG illustrations', () {
    const source =
        'https://res.cloudinary.com/demo/image/upload/v1/graphics/event.svg';

    expect(
      AppRemoteSvg.renderableUrl(source),
      'https://res.cloudinary.com/demo/image/upload/e_trim,f_png/v1/graphics/event.svg',
    );
  });

  test('leaves non-Cloudinary SVG URLs unchanged', () {
    const source = 'https://example.com/graphics/event.svg';

    expect(AppRemoteSvg.renderableUrl(source), source);
  });
}
