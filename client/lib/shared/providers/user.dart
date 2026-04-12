import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/profile/models/user.dart';
import '../../features/profile/services/user.dart';
import '../services/file.dart';

part 'user.g.dart';

@Riverpod(keepAlive: true)
class UserProfile extends _$UserProfile {
  @override
  FutureOr<User?> build() {
    // Return null synchronously. The splash screen handles session
    // validation and calls setUser() with the authenticated user.
    // An async fetch here races with setUser() and can overwrite the
    // manually-set state, causing the app to flash a white screen.
    return null;
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    String? gender,
    String? mediaId,
  }) async {
    await updateUserData({
      'name': name,
      'bio': bio,
      'gender': gender,
      'mediaId': mediaId,
    }..removeWhere((k, v) => v == null));
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() =>
        userService.updateUser(
          currentUser.id,
          data,
        ));
  }

  Future<void> updateAvatar({ImageSource source = ImageSource.gallery}) async {
    final image = await fileService.pickImage(source: source);
    if (image == null) return;

    final avatarId = await fileService.uploadFile(image, bucket: 'avatars');
    if (avatarId != null) {
      await updateProfile(mediaId: avatarId);
    }
  }

  void setUser(User? user) {
    state = AsyncData(user);
  }
}
