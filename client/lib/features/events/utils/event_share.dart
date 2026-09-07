import 'package:intl/intl.dart';

/// Plain-text body for the native share sheet.
///
/// [link] is omitted when no public share host is configured
/// (`AppConfig.shareLink` returns null), so the share degrades to a
/// text-only summary instead of a dead URL.
String buildEventShareMessage({
  required String name,
  required DateTime startTime,
  String? address,
  Uri? link,
}) {
  final trimmedAddress = address?.trim() ?? '';
  return <String>[
    name,
    DateFormat('EEE, d MMM • h:mm a').format(startTime),
    if (trimmedAddress.isNotEmpty) trimmedAddress,
    if (link != null) link.toString(),
  ].join('\n');
}
