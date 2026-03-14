String extractExceptionMessage(
  Object e, [
  String fallback = 'An unexpected error occurred',
]) {
  final msg = e.toString();
  if (msg.startsWith('Exception: ')) return msg.substring('Exception: '.length);
  if (msg == 'null' || msg.isEmpty) return fallback;
  return msg;
}
