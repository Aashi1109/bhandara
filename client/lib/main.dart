import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './shared/services/maps/map_platform_config.dart';
import './shared/theme/theme.dart';
import './router.dart';
import './shared/services/local_storage.dart';
import './shared/services/location_permission.dart';
import './shared/widgets/app_dialog.dart';
import './shared/widgets/app_session_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(configureGoogleMapsPlatform(warmupSdk: false));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('=== FLUTTER ERROR: ${details.exception} ===');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== PLATFORM ERROR: $error ===');
    return true;
  };

  await LocalStorage.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: FoodyApp()));
}

class FoodyApp extends StatefulWidget {
  const FoodyApp({super.key});

  @override
  State<FoodyApp> createState() => _FoodyAppState();
}

class _FoodyAppState extends State<FoodyApp> {
  bool _isLocationDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await LocationPermissionService.requestOnStartup();
      if (!mounted || LocationPermissionService.hasAccess(status)) return;
      await _showLocationPermissionDialog();
    });
  }

  Future<void> _showLocationPermissionDialog() async {
    if (_isLocationDialogVisible) return;
    _isLocationDialogVisible = true;

    await showAppDialog(
      context: context,
      title: 'Location Access Disabled',
      message: 'Some features will not work properly without location access.',
      primaryLabel: 'Open Settings',
      onPrimaryPressed: () async {
        await LocationPermissionService.openSettings();
      },
      secondaryLabel: 'Not now',
    );

    _isLocationDialogVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    return AppSessionCoordinator(
      child: MaterialApp.router(
        title: 'Foody',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: router,
      ),
    );
  }
}
