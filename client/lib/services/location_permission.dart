import 'package:permission_handler/permission_handler.dart';

class LocationPermissionService {
  static Future<PermissionStatus> currentStatus() {
    return Permission.locationWhenInUse.status;
  }

  static bool hasAccess(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  static Future<PermissionStatus> requestOnStartup() async {
    final status = await currentStatus();
    if (hasAccess(status)) {
      return status;
    }

    return Permission.locationWhenInUse.request();
  }

  static Future<bool> openSettings() {
    return openAppSettings();
  }
}
