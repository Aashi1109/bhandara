import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/auth.dart';
import 'user.dart';

part 'auth.g.dart';

@riverpod
class Auth extends _$Auth {
  @override
  FutureOr<bool> build() async {
    // Check if we have an active session
    final profile = await ref.watch(userProfileProvider.future);

    return profile != null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();

    final response = await authService.login(email, password);

    if (response.error != null) {
      state = AsyncError(response.error!, StackTrace.current);
    } else {
      ref.read(userProfileProvider.notifier).setUser(response.data);
      state = const AsyncData(true);
    }
  }

  Future<void> signup(Map<String, dynamic> data) async {
    state = const AsyncLoading();

    final response = await authService.signup(data);

    if (response.error != null) {
      state = AsyncError(response.error!, StackTrace.current);
    } else {
      ref.read(userProfileProvider.notifier).setUser(response.data);
      state = const AsyncData(true);
    }
  }

  Future<void> logout() async {
    await authService.logout();
    ref.read(userProfileProvider.notifier).setUser(null);
    state = const AsyncData(false);
  }
}
