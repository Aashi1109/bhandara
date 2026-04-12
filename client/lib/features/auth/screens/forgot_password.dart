import 'dart:async';

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

import './forgot_password_otp.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const String routePath = '/forgot-password';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailValid = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    try {
      await authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        unawaited(
          context.push(
            ForgotPasswordOTPScreen.routePath,
            extra: {'email': _emailController.text.trim()},
          ),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, extractExceptionMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.5),
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
                color: AppColors.muted.withValues(alpha: 0.4),
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
                  backgroundColor: AppColors.transparent,
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
                        const SizedBox(height: 24),
                        Text('Forgot Password?', style: typography.heading2),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Enter your email address and we\'ll send you a link to reset your password.',
                            textAlign: TextAlign.center,
                            style: typography.bodyLG.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppInput(
                                type: AppInputType.email,
                                label: 'Email Address',
                                placeholder: 'chef@foodie.com',
                                controller: _emailController,
                                onValidationError: (error) {
                                  setState(() {
                                    _isEmailValid =
                                        error == null &&
                                        _emailController.text.isNotEmpty;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                size: AppButtonSize.lg,
                                fullWidth: true,
                                label: 'Send Reset Link',
                                loadable: true,
                                iconRight: const Icon(LucideIcons.mail),
                                onPressed:
                                    _isEmailValid ? _handleSendResetLink : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            'Back to Login',
                            style: typography.bodyMD.copyWith(
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
          ),
        ],
      ),
    );
  }
}
