import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openInMaps({
  required double latitude,
  required double longitude,
  String? label,
}) async {
  final q = label != null && label.isNotEmpty
      ? Uri.encodeComponent(label)
      : '$latitude,$longitude';

  final Uri nativeUri;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    nativeUri = Uri.parse('maps://?q=$q&saddr=$latitude,$longitude');
  } else {
    nativeUri = Uri.parse('geo:$latitude,$longitude?q=$q');
  }

  if (await canLaunchUrl(nativeUri)) {
    await launchUrl(nativeUri);
    return;
  }

  // Fallback to Google Maps web
  final webUri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  await launchUrl(webUri, mode: LaunchMode.externalApplication);
}
