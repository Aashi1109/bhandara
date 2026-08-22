import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/events/utils/event_share.dart';

void main() {
  final startTime = DateTime(2026, 8, 22, 19, 30);

  test('buildEventShareMessage includes the link when one is configured', () {
    expect(
      buildEventShareMessage(
        name: 'Ramen Night',
        startTime: startTime,
        address: '  12 Oak Street  ',
        link: Uri.parse('https://zentry.app/event/abc'),
      ),
      'Ramen Night\n'
      'Sat, 22 Aug • 7:30 PM\n'
      '12 Oak Street\n'
      'https://zentry.app/event/abc',
    );
  });

  test('buildEventShareMessage drops a missing link and blank address', () {
    expect(
      buildEventShareMessage(
        name: 'Ramen Night',
        startTime: startTime,
        address: '   ',
      ),
      'Ramen Night\nSat, 22 Aug • 7:30 PM',
    );
  });
}
