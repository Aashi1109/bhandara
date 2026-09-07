import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/utils/error.dart';
import '../services/auth.dart';

import './auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.token, this.email});

  static const String routePath = '/forgot-password/reset';

  final String? token;
  final String? email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool _showNew = false;
  bool _showConfirm = false;
  String _newPassword = '';
  String _confirmPassword = '';

  bool get _hasLength => _newPassword.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newPassword);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPassword);
  bool get _hasSpecial => RegExp(r'[^A-Za-z0-9]').hasMatch(_newPassword);
  bool get _passwordsMatch =>
      _confirmPassword.isNotEmpty && _confirmPassword == _newPassword;
  bool get _allRequirementsMet =>
      _hasLength && _hasUppercase && _hasNumber && _hasSpecial;
  bool get _canSubmit => _allRequirementsMet && _passwordsMatch;

  Future<void> _handleReset() async {
    try {
      await authService.resetPassword(
        token: widget.token ?? '',
        email: widget.email ?? '',
        newPassword: _newPassword,
      );
      if (mounted) {
        AppSnackBar.success(context, 'Password reset successfully');
        context.go(AuthScreen.routePath);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, extractExceptionMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: context.appPalette.muted.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: context.appPalette.muted.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppHeader(
                  onBack: () => context.pop(),
                  title: '',
                  showBorder: false,
                  backgroundColor: context.appPalette.transparent,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: context.appPalette.muted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.key,
                            size: AppIconSizes.xl,
                            color: context.appPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Reset Password', style: typography.heading2),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Create a strong new password for your account.',
                            textAlign: TextAlign.center,
                            style: typography.bodyLG.copyWith(
                              color: context.appPalette.mutedForeground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.appPalette.muted,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Column(
                            children: [
                              AppInput(
                                label: 'New Password',
                                placeholder: 'Create a new password',
                                obscureText: !_showNew,
                                onChanged: (val) =>
                                    setState(() => _newPassword = val.trim()),
                                rightElement: GestureDetector(
                                  onTap: () =>
                                      setState(() => _showNew = !_showNew),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      _showNew
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: AppIconSizes.defaultSize,
                                      color: context.appPalette.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppInput(
                                label: 'Confirm New Password',
                                placeholder: 'Re-enter new password',
                                obscureText: !_showConfirm,
                                onChanged: (val) =>
                                    setState(() => _confirmPassword = val.trim()),
                                rightElement: GestureDetector(
                                  onTap: () =>
                                      setState(() => _showConfirm = !_showConfirm),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      _showConfirm
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: AppIconSizes.defaultSize,
                                      color: context.appPalette.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _PasswordRequirements(
                                hasLength: _hasLength,
                                hasUppercase: _hasUppercase,
                                hasNumber: _hasNumber,
                                hasSpecial: _hasSpecial,
                                passwordsMatch: _passwordsMatch,
                                showMatchRow: _confirmPassword.isNotEmpty,
                              ),
                              const SizedBox(height: 24),
                              AppButton(
                                size: AppButtonSize.lg,
                                fullWidth: true,
                                label: 'Reset Password',
                                loadable: true,
                                iconRight: const Icon(LucideIcons.checkCircle2),
                                onPressed: _canSubmit ? _handleReset : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({
    required this.hasLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecial,
    required this.passwordsMatch,
    required this.showMatchRow,
  });

  final bool hasLength;
  final bool hasUppercase;
  final bool hasNumber;
  final bool hasSpecial;
  final bool passwordsMatch;
  final bool showMatchRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementRow(label: 'Minimum 8 characters', met: hasLength),
        const SizedBox(height: 8),
        _RequirementRow(label: 'At least one uppercase letter', met: hasUppercase),
        const SizedBox(height: 8),
        _RequirementRow(label: 'Contains a number', met: hasNumber),
        const SizedBox(height: 8),
        _RequirementRow(
          label: 'Contains a special character',
          met: hasSpecial,
        ),
        if (showMatchRow) ...[
          const SizedBox(height: 8),
          _RequirementRow(label: 'Passwords match', met: passwordsMatch),
        ],
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Row(
      spacing: 8,
      children: [
        Icon(
          met ? LucideIcons.checkCircle2 : LucideIcons.circle,
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
