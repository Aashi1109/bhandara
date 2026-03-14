import 'dart:async';
import 'package:flutter/foundation.dart';

/// A utility class for debouncing actions.
///
/// Useful for search fields, window resizing, or any high-frequency events
/// that should only trigger once after a period of inactivity.
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;

  /// Runs [action] after the specified [delay].
  ///
  /// If [run] is called again before the timer expires,
  /// the previous timer is cancelled and a new one starts.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Explicitly cancels any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels any pending action and cleans up resources.
  void dispose() {
    cancel();
  }
}
