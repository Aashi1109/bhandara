import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user.dart';
import '../services/auth.dart';
import 'user.dart';

part 'auth.g.dart';

@riverpod
class Auth extends _$Auth {
  @override
  FutureOr<bool> build() async {
    final profile = await ref.watch(userProfileProvider.future);
    return profile != null;
  }

  Future<User> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await authService.login(email, password);
      ref.read(userProfileProvider.notifier).setUser(user);
      state = const AsyncData(true);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<User> signup(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      final user = await authService.signup(data);
      ref.read(userProfileProvider.notifier).setUser(user);
      state = const AsyncData(true);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await authService.logout();
    ref.read(userProfileProvider.notifier).setUser(null);
    state = const AsyncData(false);
  }
}
