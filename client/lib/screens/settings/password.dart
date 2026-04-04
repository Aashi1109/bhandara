import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/input.dart';
import '../../widgets/settings_action_footer.dart';

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
    return Scaffold(
      backgroundColor: AppColors.surface,
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
                        decoration: const BoxDecoration(
                          color: AppColors.muted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.lock,
                          size: AppIconSizes.xl,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Update Security',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Please enter your current password to create a new one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
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
                        color: AppColors.mutedForeground,
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
                        color: AppColors.mutedForeground,
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
                      const Text(
                        'FAIR PASSWORD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.mutedForeground,
                        ),
                      ),
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
                        color: AppColors.mutedForeground,
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
          color: filled ? AppColors.primary : AppColors.muted,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _requirementItem(String label, bool met) {
    return Row(
      spacing: 8,
      children: [
        Icon(
          met ? LucideIcons.check : LucideIcons.x,
          size: AppIconSizes.s,
          color: met
              ? AppColors.primary
              : AppColors.mutedForeground.withValues(alpha: 0.4),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: met
                ? AppColors.primary
                : AppColors.mutedForeground.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
