import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foody_mobile/shared/providers/login_flow.dart';

void main() {
  group('LoginFlow', () {
    test(
      'replace resets stale user data before starting a new auth attempt',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(loginFlowProvider.notifier);

        notifier.update({
          'id': 'existing-user-id',
          'email': 'existing@example.com',
          'isSocialLogin': false,
        });

        notifier.replace({'email': 'new@example.com'});

        final state = container.read(loginFlowProvider);
        expect(state.email, 'new@example.com');
        expect(state.data.containsKey('id'), isFalse);
        expect(state.data.containsKey('isSocialLogin'), isFalse);
      },
    );
  });
}
