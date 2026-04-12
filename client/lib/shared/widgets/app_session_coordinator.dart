import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/socket_events.dart';
import '../../features/profile/models/user.dart';
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
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

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

    _socketSubscription = socketService.messages.listen((event) {
      final eventName = event['event'];
      if (eventName != SocketEvents.userUpdate) {
        return;
      }

      final payload = event['data'];
      final userMap = payload is Map<String, dynamic>
          ? payload
          : payload is Map
          ? Map<String, dynamic>.from(payload)
          : null;
      if (userMap == null) {
        return;
      }

      final currentUser = ref.read(userProfileProvider).value;
      final updatedUserId = userMap['id'] as String?;
      if (currentUser == null || updatedUserId == null || currentUser.id != updatedUserId) {
        return;
      }

      ref.read(userProfileProvider.notifier).setUser(User.fromJson(userMap));
    });
  }

  @override
  void dispose() {
    apiService.onUnauthorized = null;
    _socketSubscription?.cancel();
    _userSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
