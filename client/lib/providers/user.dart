import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user.dart';
import '../services/user.dart';
import '../services/file.dart';

part 'user.g.dart';

@riverpod
class UserProfile extends _$UserProfile {
  @override
  FutureOr<User?> build() async {
    try {
      return await userService.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    String? mediaId,
  }) async {
    await updateUserData({
      'name': name,
      'bio': bio,
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
