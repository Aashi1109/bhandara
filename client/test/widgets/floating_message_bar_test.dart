import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/widgets/floating_message_bar.dart';

void main() {
  Future<void> pumpFloatingMessageBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FloatingMessageBar(onSend: (_, _) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder findMessageInput() => find.byType(TextField);
  Finder findEmojiToggle() =>
      find.byKey(const ValueKey('floating_message_bar_emoji_toggle'));
  Finder findEmojiPicker() =>
      find.byKey(const ValueKey('floating_message_bar_emoji_picker'));

  testWidgets('tapping smile toggles emoji picker', (tester) async {
    await pumpFloatingMessageBar(tester);

    expect(findEmojiPicker(), findsNothing);

    await tester.tap(findEmojiToggle());
    await tester.pumpAndSettle();

    expect(findEmojiPicker(), findsOneWidget);

    await tester.tap(findEmojiToggle());
    await tester.pumpAndSettle();

    expect(findEmojiPicker(), findsNothing);
  });

  testWidgets('focusing text field hides emoji picker', (tester) async {
    await pumpFloatingMessageBar(tester);

    await tester.tap(findEmojiToggle());
    await tester.pumpAndSettle();
    expect(findEmojiPicker(), findsOneWidget);

    await tester.tap(findMessageInput());
    await tester.pumpAndSettle();

    expect(findEmojiPicker(), findsNothing);
  });

  testWidgets('selecting emoji inserts at current caret position', (
    tester,
  ) async {
    await pumpFloatingMessageBar(tester);

    await tester.tap(findMessageInput());
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Hi there',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();

    await tester.tap(findEmojiToggle());
    await tester.pumpAndSettle();

    final emojiPicker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    emojiPicker.onEmojiSelected!(
      Category.SMILEYS,
      const Emoji('😀', 'grinning'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi😀 there'), findsOneWidget);
    expect(findEmojiPicker(), findsOneWidget);
  });
}
