import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/settings_action_footer.dart';

class PasswordSettingsScreen extends StatefulWidget {
  const PasswordSettingsScreen({super.key});

  static const String routePath = '/settings/password';
  static const String _settingsRoutePath = '/settings';

  @override
  State<PasswordSettingsScreen> createState() => _PasswordSettingsScreenState();
}

class _PasswordSettingsScreenState extends State<PasswordSettingsScreen> {
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String _currentPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';

  bool get _hasLength => _newPassword.length >= 8;
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPassword);
  bool get _hasSpecial => RegExp(r'[^A-Za-z0-9]').hasMatch(_newPassword);
  bool get _passwordsMatch =>
      _confirmPassword.isNotEmpty && _confirmPassword == _newPassword;
  bool get _canSubmit =>
      _currentPassword.isNotEmpty &&
      _newPassword.isNotEmpty &&
      _hasLength &&
      _hasNumber &&
      _hasSpecial &&
      _passwordsMatch;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Change Password',
            onBack: () => context.go(PasswordSettingsScreen._settingsRoutePath),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.appPalette.muted,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.lock,
                          size: AppIconSizes.xl,
                          color: context.appPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Update Security',
                        style: typography.titleLG.copyWith(
                          color: context.appPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Please enter your current password to create a new one.',
                          textAlign: TextAlign.center,
                          style: typography.bodyMD.copyWith(
                            color: context.appPalette.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  AppInput(
                    label: 'Current Password',
                    placeholder: '••••••••',
                    obscureText: !_showCurrent,
                    onChanged: (val) =>
                        setState(() => _currentPassword = val.trim()),
                    rightElement: GestureDetector(
                      onTap: () => setState(() => _showCurrent = !_showCurrent),
                      child: Icon(
                        _showCurrent ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: AppIconSizes.defaultSize,
                        color: context.appPalette.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppInput(
                    label: 'New Password',
                    placeholder: 'Create a new password',
                    obscureText: !_showNew,
                    onChanged: (val) =>
                        setState(() => _newPassword = val.trim()),
                    rightElement: GestureDetector(
                      onTap: () => setState(() => _showNew = !_showNew),
                      child: Icon(
                        _showNew ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: AppIconSizes.defaultSize,
                        color: context.appPalette.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _passwordStrengthBar(_newPassword.isNotEmpty),
                          const SizedBox(width: 4),
                          _passwordStrengthBar(_newPassword.length > 4),
                          const SizedBox(width: 4),
                          _passwordStrengthBar(_newPassword.length > 8),
                          const SizedBox(width: 4),
                          _passwordStrengthBar(_newPassword.length > 10),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('FAIR PASSWORD', style: typography.overline),
                      const SizedBox(height: 12),
                      _requirementItem('At least 8 characters', _hasLength),
                      const SizedBox(height: 8),
                      _requirementItem('Contains a number', _hasNumber),
                      const SizedBox(height: 8),
                      _requirementItem(
                        'Contains a special character',
                        _hasSpecial,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppInput(
                    label: 'Confirm New Password',
                    placeholder: 'Re-enter new password',
                    obscureText: !_showConfirm,
                    onChanged: (val) =>
                        setState(() => _confirmPassword = val.trim()),
                    rightElement: GestureDetector(
                      onTap: () => setState(() => _showConfirm = !_showConfirm),
                      child: Icon(
                        _showConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: AppIconSizes.defaultSize,
                        color: context.appPalette.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsActionFooter(
            label: 'Update Password',
            onPressed: _canSubmit ? () {} : null,
          ),
        ],
      ),
    );
  }

  Widget _passwordStrengthBar(bool filled) {
    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: filled ? context.appPalette.primary : context.appPalette.muted,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _requirementItem(String label, bool met) {
    final typography = context.appTypography;
    return Row(
      spacing: 8,
      children: [
        Icon(
          met ? LucideIcons.check : LucideIcons.x,
          size: AppIconSizes.s,
          color: met
              ? context.appPalette.primary
              : context.appPalette.mutedForeground.withValues(alpha: 0.4),
        ),
        Text(
          label,
          style: typography.bodySMStrong.copyWith(
            color: met
                ? context.appPalette.primary
                : context.appPalette.mutedForeground.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
