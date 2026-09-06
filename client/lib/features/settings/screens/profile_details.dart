import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/settings_action_footer.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/tabs.dart';
import '../../../shared/widgets/textarea.dart';
import '../../profile/models/user.dart';
import '../../../shared/providers/user.dart';
import '../../../shared/widgets/snackbar.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  static const String routePath = '/settings/profile';
  static const String _settingsRoutePath = '/settings';

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  static const List<AppTabItem<String>> _genderItems = [
    AppTabItem(label: 'Male', value: 'male', icon: '♂'),
    AppTabItem(label: 'Female', value: 'female', icon: '♀'),
    AppTabItem(label: 'Other', value: 'other', icon: '⋯'),
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _didHydrate = false;
  String _initialName = '';
  String _initialBio = '';
  String _gender = 'other';
  String _initialGender = 'other';

  String get _currentName => _nameController.text.trim();
  String get _currentBio => _bioController.text.trim();
  String get _currentGender => _gender;
  bool get _isDirty =>
      _currentName != _initialName ||
      _currentBio != _initialBio ||
      _currentGender != _initialGender;

  String _normalizeGender(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'male':
      case 'female':
      case 'other':
        return value!.trim().toLowerCase();
      default:
        return 'other';
    }
  }

  void _hydrate(User? user) {
    if (_didHydrate || user == null) return;

    final gender = _normalizeGender(user.gender);
    _nameController.text = user.name ?? '';
    _bioController.text = user.bio ?? '';
    _gender = gender;
    _initialName = (user.name ?? '').trim();
    _initialBio = (user.bio ?? '').trim();
    _initialGender = gender;
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
    final gender = _currentGender;

    try {
      await ref
          .read(userProfileProvider.notifier)
          .updateProfile(name: name, bio: bio, gender: gender);

      if (mounted) {
        setState(() {
          _initialName = name;
          _initialBio = bio;
          _initialGender = gender;
          _gender = gender;
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

  Widget _buildLoadingState() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(height: 16),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AppSkeleton(width: 96, height: 96, shape: BoxShape.circle),
                AppSkeleton(width: 32, height: 32, shape: BoxShape.circle),
              ],
            ),
          ),
          SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSkeletonLine(width: 96, height: 12),
          ),
          SizedBox(height: 12),
          AppSkeleton(
            height: 56,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSkeletonLine(width: 72, height: 12),
          ),
          SizedBox(height: 12),
          AppSkeleton(
            height: 56,
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSkeletonLine(width: 84, height: 12),
          ),
          SizedBox(height: 12),
          AppSkeleton(
            height: 152,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.value;
    _hydrate(user);
    final isSaving = userAsync.isLoading && _didHydrate;
    final typography = context.appTypography;

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Profile Details',
            onBack: () => context.go(ProfileDetailsScreen._settingsRoutePath),
          ),
          Expanded(
            child: userAsync.when(
              loading: _buildLoadingState,
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
                                      color: context.appPalette.border,
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
                                            colorFilter: ColorFilter.mode(
                                              context.appPalette.mutedForeground,
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
                                    color: context.appPalette.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.appPalette.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.appPalette.primary.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    LucideIcons.edit2,
                                    size: AppIconSizes.m,
                                    color: context.appPalette.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to change photo',
                            style: typography.bodyMD.copyWith(
                              color: context.appPalette.mutedForeground,
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gender',
                        style: typography.labelMD.copyWith(
                          color: context.appPalette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTabs<String>(
                      currentValue: _gender,
                      onChanged: (value) => setState(() => _gender = value),
                      items: _genderItems,
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
