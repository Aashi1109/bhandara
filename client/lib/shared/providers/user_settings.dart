import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/profile/models/user.dart' as user_models;
import '../../features/profile/services/user.dart';

part 'user_settings.g.dart';

@Riverpod(keepAlive: true)
class UserSettings extends _$UserSettings {
  @override
  FutureOr<user_models.UserSettings?> build() {
    // Return null synchronously. Callers invoke loadSettings() explicitly after
    // authentication, mirroring the UserProfile provider pattern.
    return null;
  }

  Future<void> loadSettings(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => userService.getSettings(userId),
    );
  }

  Future<void> updateSettings(
    String userId,
    Map<String, dynamic> data,
  ) async {
    state = await AsyncValue.guard(
      () => userService.updateSettings(userId, data),
    );
  }

  void setSettings(user_models.UserSettings? settings) {
    state = AsyncData(settings);
  }
}
