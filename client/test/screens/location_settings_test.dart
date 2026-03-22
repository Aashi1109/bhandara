import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/models/location_picker.dart';
import 'package:foody_mobile/models/user.dart';
import 'package:foody_mobile/screens/settings/location.dart';

void main() {
  testWidgets('picker mode returns selected location without profile save', (
    tester,
  ) async {
    UserAddress? pickedResult;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      pickedResult = await Navigator.of(context).push<UserAddress>(
                        MaterialPageRoute(
                          builder: (_) => LocationSettingsScreen(
                            mode: LocationSelectionMode.picker,
                            initialLocation: UserAddress(
                              label: 'Civil Lines, Nagpur',
                              latitude: 21.1498,
                              longitude: 79.0806,
                            ),
                            useStaticMapPlaceholder: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Select Location'), findsOneWidget);
    expect(find.text('Use This Location'), findsOneWidget);

    await tester.tap(find.text('Use This Location'));
    await tester.pumpAndSettle();

    expect(pickedResult, isNotNull);
    expect(pickedResult!.label, 'Civil Lines, Nagpur');
  });
}
