import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/user.dart';
import '../services/api.dart';
import '../services/socket.dart';

class AppSessionCoordinator extends ConsumerStatefulWidget {
  const AppSessionCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppSessionCoordinator> createState() =>
      _AppSessionCoordinatorState();
}

class _AppSessionCoordinatorState extends ConsumerState<AppSessionCoordinator> {
  ProviderSubscription<AsyncValue<User?>>? _userSubscription;

  @override
  void initState() {
    super.initState();

    apiService.onUnauthorized = () async {
      await socketService.endAuthenticatedSession();
      ref.read(userProfileProvider.notifier).setUser(null);
    };

    _userSubscription = ref.listenManual<AsyncValue<User?>>(
      userProfileProvider,
      (previous, next) {
        final previousUser = previous?.value;
        final nextUser = next.value;

        if (nextUser != null) {
          unawaited(socketService.startAuthenticatedSession());
          return;
        }

        if (previousUser != null) {
          unawaited(socketService.endAuthenticatedSession());
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    apiService.onUnauthorized = null;
    _userSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
