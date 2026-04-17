import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnreadNotificationCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

final unreadNotificationCountProvider =
    NotifierProvider<UnreadNotificationCountNotifier, int>(
  UnreadNotificationCountNotifier.new,
);
