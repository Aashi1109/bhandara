import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/models/location_picker.dart';
import 'package:foody_mobile/models/user.dart';
import 'package:foody_mobile/providers/user.dart';
import 'package:foody_mobile/screens/settings/location.dart';
import 'package:foody_mobile/widgets/button.dart';

void main() {
  testWidgets('picker mode returns selected location without profile save', (
    tester,
  ) async {
    LocationPickerResult? pickedResult;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      pickedResult =
                          await Navigator.of(context).push<LocationPickerResult>(
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
    expect(pickedResult!.location.label, 'Civil Lines, Nagpur');
  });

  testWidgets('settings mode keeps confirm button disabled on initial load', (
    tester,
  ) async {
    final user = User(
      id: 'user-1',
      email: 'test@example.com',
      address: UserAddress(
        label: 'Civil Lines, Nagpur',
        latitude: 21.1498,
        longitude: 79.0806,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(() => _TestUserProfile(user)),
        ],
        child: const MaterialApp(
          home: LocationSettingsScreen(useStaticMapPlaceholder: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Confirm Location'),
    );
    expect(button.onPressed, isNull);
  });
}

class _TestUserProfile extends UserProfile {
  _TestUserProfile(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}
