import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/header.dart';
import '../widgets/button.dart';
import '../services/auth.dart';
import '../providers/user.dart';
import 'profile.dart';
import 'settings/profile_details.dart';
import 'settings/email.dart';
import 'settings/password.dart';
import 'settings/cuisines.dart';
import 'settings/location.dart';
import 'settings/notifications.dart';
import 'auth.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  static const String routePath = '/settings';
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _locationSharing = true;
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
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
                  Builder(builder: (context) {
                    final user = ref.watch(userProfileProvider).value;
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
                                        errorBuilder: (_, __, ___) => Icon(
                                          LucideIcons.user,
                                          size: 32,
                                          color: AppColors.mutedForeground
                                              .withValues(alpha: 0.4),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          LucideIcons.user,
                                          size: 32,
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
                                onTap: () =>
                                    context.go(ProfileDetailsScreen.routePath),
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
                                    size: 12,
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 32),

                  // Account Information
                  _sectionLabel('ACCOUNT INFORMATION'),
                  const SizedBox(height: 12),
                  _settingContainer([
                    _settingItem(
                      LucideIcons.mail,
                      'Email',
                      'alex.johnson@example.com',
                      onTap: () => context.go(EmailSettingsScreen.routePath),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.lock,
                      'Change Password',
                      'Update your security',
                      onTap: () => context.go(PasswordSettingsScreen.routePath),
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Preferences
                  _sectionLabel('PREFERENCES'),
                  const SizedBox(height: 12),
                  _settingContainer([
                    _settingItem(
                      LucideIcons.utensils,
                      'Cuisine Interests',
                      'Vegan, Asian',
                      onTap: () => context.go(CuisineInterestsScreen.routePath),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.mapPin,
                      'Default Location',
                      'San Francisco',
                      onTap: () => context.go(LocationSettingsScreen.routePath),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.bell,
                      'Notifications',
                      'Configure alerts',
                      onTap: () =>
                          context.go(NotificationsSettingsScreen.routePath),
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
                      (val) => setState(() => _locationSharing = val),
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.shield,
                      'Data & Privacy',
                      'Your data controls',
                      onTap: () => {},
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
                      onTap: () => {},
                      showBorder: true,
                    ),
                    _settingItem(
                      LucideIcons.info,
                      'About App',
                      'v2.4.0',
                      onTap: () => {},
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Sign out
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.xl,
                    fullWidth: true,
                    onPressed: _isSigningOut
                        ? null
                        : () async {
                            setState(() => _isSigningOut = true);
                            await authService.logout();
                            ref.read(userProfileProvider.notifier).setUser(null);
                            if (!context.mounted) return;
                            context.go(AuthScreen.routePath);
                          },
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.logOut, size: 20),
                    label: 'Sign Out',
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'FOODEVENTS INC. © 2024',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.mutedForeground,
                      ),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _settingItem(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    bool showBorder = false,
  }) {
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
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppColors.mutedForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.mutedForeground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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
