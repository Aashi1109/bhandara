import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/providers/auth.dart';
import '../../../shared/providers/tag.dart';
import '../../../shared/providers/user.dart';
import '../../../shared/providers/user_settings.dart';
import '../../profile/screens/profile.dart';
import './profile_details.dart';
import './email.dart';
import './password.dart';
import './cuisines.dart';
import './location.dart';
import './notifications.dart';
import './data_privacy.dart';
import './help_support.dart';
import './about.dart';
import '../../auth/screens/auth.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const String routePath = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _locationSharing = true;
  bool _isSigningOut = false;
  bool _didSyncLocationSharing = false;

  Future<void> _updateShareLocation(bool value) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    setState(() => _locationSharing = value);
    await ref.read(userSettingsProvider.notifier).updateSettings(user.id, {
      'privacy': {'shareLocation': value},
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.value;
    final settingsPrivacy = ref.watch(userSettingsProvider).value?.privacy;
    if (!_didSyncLocationSharing && settingsPrivacy != null) {
      _locationSharing = settingsPrivacy.shareLocation;
      _didSyncLocationSharing = true;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Settings',
            onBack: () => context.go(ProfileScreen.routePath),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile summary
                  Builder(
                    builder: (context) {
                      return Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.muted,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ClipOval(
                                  child: user?.avatarUrl != null
                                      ? Image.network(
                                          user!.avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Icon(
                                            LucideIcons.user,
                                            size: AppIconSizes.xl,
                                            color: AppColors.mutedForeground
                                                .withValues(alpha: 0.4),
                                          ),
                                        )
                                      : Center(
                                          child: Icon(
                                            LucideIcons.user,
                                            size: AppIconSizes.xl,
                                            color: AppColors.mutedForeground
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => context.push(
                                    ProfileDetailsScreen.routePath,
                                  ),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      LucideIcons.edit2,
                                      size: AppIconSizes.xs,
                                      color: AppColors.surface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? user?.email ?? 'User',
                                  style: context.appTypography.titleLG.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? '',
                                  style: context.appTypography.bodyMD.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Account Information
                  _sectionLabel('ACCOUNT INFORMATION'),
                  const SizedBox(height: 12),
                  _settingContainer([
                    _settingItem(
                      LucideIcons.mail,
                      'Email',
                      user?.email ?? '',
                      onTap: () => context.push(EmailSettingsScreen.routePath),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.alignLeft,
                      'Bio',
                      user?.bio?.trim().isNotEmpty == true
                          ? user!.bio!.trim()
                          : 'Add a short bio',
                      onTap: () => context.push(ProfileDetailsScreen.routePath),
                      showBorder: !(user?.isSocialLogin ?? false),
                    ),
                    if (!(user?.isSocialLogin ?? false))
                      _settingItem(
                        LucideIcons.lock,
                        'Change Password',
                        'Update your security',
                        onTap: () =>
                            context.push(PasswordSettingsScreen.routePath),
                      ),
                  ]),
                  const SizedBox(height: 32),

                  // Preferences
                  _sectionLabel('PREFERENCES'),
                  const SizedBox(height: 12),
                  _settingContainer([
                    Builder(
                      builder: (context) {
                        final interestIds =
                            ref.watch(userSettingsProvider).value?.interests ??
                            const [];
                        final allTags =
                            ref.watch(tagsProvider(rootOnly: true)).value ??
                            const [];
                        final matched = allTags
                            .where((t) => interestIds.contains(t.id))
                            .take(2)
                            .map((t) => t.name)
                            .join(', ');
                        final label = matched.isEmpty
                            ? 'No cuisines selected'
                            : matched;
                        return _settingItem(
                          LucideIcons.utensils,
                          'Cuisine Interests',
                          label,
                          onTap: () =>
                              context.push(CuisineInterestsScreen.routePath),
                          showBorder: true,
                        );
                      },
                    ),
                    _settingItem(
                      LucideIcons.mapPin,
                      'Default Location',
                      user?.address?.label.isNotEmpty == true
                          ? user!.address!.label
                          : 'Not set',
                      onTap: () =>
                          context.push(LocationSettingsScreen.routePath),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.bell,
                      'Notifications',
                      'Configure alerts',
                      onTap: () =>
                          context.push(NotificationsSettingsScreen.routePath),
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Privacy
                  _sectionLabel('PRIVACY'),
                  const SizedBox(height: 12),
                  _settingContainer([
                    _toggleItem(
                      LucideIcons.mapPin,
                      'Share Location',
                      'Visible on active events',
                      _locationSharing,
                      _updateShareLocation,
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.shield,
                      'Data & Privacy',
                      'Your data controls',
                      onTap: () => context.push(DataPrivacyScreen.routePath),
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Support
                  _sectionLabel('SUPPORT'),
                  const SizedBox(height: 12),
                  _settingContainer([
                    _settingItem(
                      LucideIcons.helpCircle,
                      'Help & Support',
                      'FAQs and guides',
                      onTap: () => context.push(HelpSupportScreen.routePath),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.info,
                      'About App',
                      'v2.4.0',
                      onTap: () => context.push(AboutAppScreen.routePath),
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Sign out
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.xl,
                    fullWidth: true,
                    loadable: true,
                    onPressed: _isSigningOut
                        ? null
                        : () async {
                            setState(() => _isSigningOut = true);
                            try {
                              await ref.read(authProvider.notifier).logout();
                              if (!context.mounted) return;
                              context.go(AuthScreen.routePath);
                            } finally {
                              if (mounted) {
                                setState(() => _isSigningOut = false);
                              }
                            }
                          },
                    icon: const Icon(
                      LucideIcons.logOut,
                      size: AppIconSizes.defaultSize,
                    ),
                    label: 'Sign Out',
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'FOODEVENTS INC. © 2024',
                      style: context.appTypography.overline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _sectionLabel(String text) {
    final typography = context.appTypography;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: typography.overline),
    );
  }

  Widget _settingItem(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    bool showBorder = false,
  }) {
    final typography = context.appTypography;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.m,
                color: AppColors.mutedForeground,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.labelMD.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.labelSMRegular.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: AppIconSizes.m,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool showBorder = false,
  }) {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppIconSizes.m,
              color: AppColors.mutedForeground,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.labelMD.copyWith(color: AppColors.primary),
                ),
                Text(
                  subtitle,
                  style: typography.labelSMRegular.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
