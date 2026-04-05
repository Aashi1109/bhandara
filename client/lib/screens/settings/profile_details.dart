import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../../widgets/settings_action_footer.dart';
import '../../widgets/textarea.dart';
import '../../models/user.dart';
import '../../providers/user.dart';
import '../../widgets/snackbar.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  static const String routePath = '/settings/profile';
  static const String _settingsRoutePath = '/settings';

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _didHydrate = false;
  String _initialName = '';
  String _initialBio = '';

  String get _currentName => _nameController.text.trim();
  String get _currentBio => _bioController.text.trim();
  bool get _isDirty =>
      _currentName != _initialName || _currentBio != _initialBio;

  void _hydrate(User? user) {
    if (_didHydrate || user == null) return;

    _nameController.text = user.name ?? '';
    _bioController.text = user.bio ?? '';
    _initialName = (user.name ?? '').trim();
    _initialBio = (user.bio ?? '').trim();
    _didHydrate = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null || !_isDirty) return;

    FocusScope.of(context).unfocus();
    final name = _currentName;
    final bio = _currentBio;

    try {
      await ref
          .read(userProfileProvider.notifier)
          .updateProfile(name: name, bio: bio);

      if (mounted) {
        setState(() {
          _initialName = name;
          _initialBio = bio;
          _nameController.text = name;
          _bioController.text = bio;
        });
        AppSnackBar.show(
          context,
          message: 'Profile updated successfully',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: e.toString(),
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _updateAvatar() async {
    try {
      await ref.read(userProfileProvider.notifier).updateAvatar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Failed to update photo: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.value;
    _hydrate(user);
    final isSaving = userAsync.isLoading && _didHydrate;
    final typography = context.appTypography;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Profile Details',
            onBack: () => context.go(ProfileDetailsScreen._settingsRoutePath),
          ),
          Expanded(
            child: userAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $err'),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Retry',
                      onPressed: () => ref.refresh(userProfileProvider),
                    ),
                  ],
                ),
              ),
              data: (user) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _updateAvatar,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: user?.avatarUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: user!.avatarUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const CircularProgressIndicator(),
                                          )
                                        : ColorFiltered(
                                            colorFilter: const ColorFilter.mode(
                                              AppColors.mutedForeground,
                                              BlendMode.saturation,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  'https://picsum.photos/seed/${user?.id ?? 'default'}/200/200',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                  ),
                                ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    LucideIcons.edit2,
                                    size: AppIconSizes.m,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to change photo',
                            style: typography.bodyMD.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    AppInput(
                      label: 'Display Name',
                      placeholder: 'Enter your full name',
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      borderRadius: 16,
                    ),
                    const SizedBox(height: 24),
                    AppTextArea(
                      label: 'Bio',
                      placeholder: 'Tell us a bit about yourself...',
                      controller: _bioController,
                      onChanged: (_) => setState(() {}),
                      height: 132,
                      minLines: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SettingsActionFooter(
            label: isSaving ? 'Updating...' : 'Update Profile',
            onPressed: user == null || !_isDirty || isSaving
                ? null
                : _saveProfile,
          ),
        ],
      ),
    );
  }
}
