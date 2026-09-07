import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/theme/theme.dart';

const _constSurfaceKey = Key('const-surface');

class _PaletteSurface extends StatelessWidget {
  const _PaletteSurface(this.surfaceKey);

  final Key surfaceKey;

  @override
  Widget build(BuildContext context) {
    return Container(key: surfaceKey, color: context.appPalette.surface);
  }
}

void main() {
  testWidgets('palette surfaces update when the app theme changes', (
    tester,
  ) async {
    final normalSurfaceKey = UniqueKey();

    Widget buildApp(AppPalette palette) {
      return MaterialApp(
        theme: AppTheme.buildTheme(palette),
        home: Column(
          children: [
            _PaletteSurface(normalSurfaceKey),
            const _PaletteSurface(_constSurfaceKey),
          ],
        ),
      );
    }

    await tester.pumpWidget(buildApp(lightPalette));

    expect(
      tester.widget<Container>(find.byKey(normalSurfaceKey)).color,
      lightPalette.surface,
    );
    expect(
      tester.widget<Container>(find.byKey(_constSurfaceKey)).color,
      lightPalette.surface,
    );

    await tester.pumpWidget(buildApp(darkPalette));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Container>(find.byKey(normalSurfaceKey)).color,
      darkPalette.surface,
    );
    expect(
      tester.widget<Container>(find.byKey(_constSurfaceKey)).color,
      darkPalette.surface,
    );
  });
}
