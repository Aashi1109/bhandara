import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionService {
  static Future<PermissionStatus> currentStatus({
    bool isWeb = kIsWeb,
    Future<PermissionStatus> Function()? statusLoader,
  }) {
    if (isWeb) {
      return Future.value(PermissionStatus.granted);
    }

    return (statusLoader ?? _currentPermissionStatus)();
  }

  static bool hasAccess(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  static Future<PermissionStatus> requestOnStartup({
    bool isWeb = kIsWeb,
    Future<PermissionStatus> Function()? statusLoader,
    Future<PermissionStatus> Function()? permissionRequester,
  }) async {
    final status = await currentStatus(
      isWeb: isWeb,
      statusLoader: statusLoader,
    );
    if (hasAccess(status)) {
      return status;
    }

    if (isWeb) {
      return status;
    }

    return (permissionRequester ?? _requestPermission)();
  }

  static Future<bool> openSettings({
    bool isWeb = kIsWeb,
    Future<bool> Function()? appSettingsOpener,
  }) {
    if (isWeb) {
      return Future.value(false);
    }

    return (appSettingsOpener ?? _openAppSettings)();
  }

  static Future<PermissionStatus> _currentPermissionStatus() {
    return Permission.locationWhenInUse.status;
  }

  static Future<PermissionStatus> _requestPermission() {
    return Permission.locationWhenInUse.request();
  }

  static Future<bool> _openAppSettings() {
    return openAppSettings();
  }
}
