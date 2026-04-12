import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/shared/widgets/app_pull_to_refresh.dart';

void main() {
  testWidgets('triggers refresh for short content', (tester) async {
    var refreshCount = 0;
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPullToRefresh(
            onRefresh: () {
              refreshCount += 1;
              return completer.future;
            },
            child: const Center(child: Text('Short content')),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(Scrollable), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });
}
