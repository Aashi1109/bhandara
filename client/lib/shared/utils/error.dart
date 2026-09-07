import 'dart:async';

String extractExceptionMessage(Object e, [
  String fallback = 'An unexpected error occurred',
]) {
  if (e is TimeoutException) return 'Request timed out — please check your connection and try again';
  final msg = e.toString();
  if (msg.startsWith('Exception: ')) return msg.substring('Exception: '.length);
  if (msg == 'null' || msg.isEmpty) return fallback;
  return msg;
}
