import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/services/location_permission.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('LocationPermissionService', () {
    test('short-circuits permission status checks on web', () async {
      var called = false;

      final status = await LocationPermissionService.currentStatus(
        isWeb: true,
        statusLoader: () async {
          called = true;
          return PermissionStatus.denied;
        },
      );

      expect(status, PermissionStatus.granted);
      expect(called, isFalse);
    });

    test('does not invoke permission request on web startup', () async {
      var requestCalled = false;

      final status = await LocationPermissionService.requestOnStartup(
        isWeb: true,
        permissionRequester: () async {
          requestCalled = true;
          return PermissionStatus.denied;
        },
      );

      expect(status, PermissionStatus.granted);
      expect(requestCalled, isFalse);
    });

    test('does not try to open app settings on web', () async {
      var settingsCalled = false;

      final opened = await LocationPermissionService.openSettings(
        isWeb: true,
        appSettingsOpener: () async {
          settingsCalled = true;
          return true;
        },
      );

      expect(opened, isFalse);
      expect(settingsCalled, isFalse);
    });
  });
}
