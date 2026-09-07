import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/login_flow.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/providers/auth.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/utils/auth_redirect.dart';
import '../../../shared/utils/error.dart';
import '../../../shared/widgets/password_requirements.dart';

import './auth.dart';
import './forgot_password.dart';
import '../../onboarding/screens/profile_setup.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.extra});

  static const String routePath = '/login';
  final Map<String, dynamic>? extra;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showPassword = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) return;

    final flowState = ref.read(loginFlowProvider);
    final email = flowState.email;
    if (email == null || email.isEmpty) {
      context.go(AuthScreen.routePath);
      return;
    }

    if (mounted) {
      try {
        final flowState = ref.read(loginFlowProvider);
        final isNewUser =
            flowState.data.isEmpty || flowState.data['id'] == null;

        if (isNewUser) {
          ref.read(loginFlowProvider.notifier).update({
            'password': _passwordController.text,
          });
          unawaited(context.push(ProfileSetupScreen.routePath));
          return;
        } else {
          final user = await ref
              .read(authProvider.notifier)
              .login(email, _passwordController.text);

          if (!mounted) return;
          ref.invalidate(loginFlowProvider);
          context.go(routeForAuthenticatedUser(user));
        }
      } catch (e) {
        if (!mounted) return;
        final message = extractExceptionMessage(e);
        AppSnackBar.error(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final bool isNewUser = ref.watch(loginFlowProvider).data['id'] == null;
    debugPrint('isNewUser: $isNewUser');

    final email = ref.watch(loginFlowProvider).email ?? 'User';
    final initial = email.isNotEmpty && email != 'User'
        ? email[0].toUpperCase()
        : 'U';

    final passwordRequirements = PasswordRequirements(
      password: _passwordController.text,
    );

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Stack(
        children: [
          // Background Gradients (Simulated)
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
                        const SizedBox(height: 32),
                        Text('Welcome back', style: typography.heading2),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your password to continue',
                          style: typography.bodyLG,
                        ),
                        const SizedBox(height: 40),

                        // User Badge
                        LayoutBuilder(
                          builder: (context, constraints) => Container(
                            width: constraints.maxWidth,
                            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                            decoration: BoxDecoration(
                              color: context.appPalette.surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: context.appPalette.border),
                              boxShadow: [
                                BoxShadow(
                                  color: context.appPalette.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: context.appPalette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: typography.labelSM.copyWith(
                                        color: context.appPalette.surface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.labelMD,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  LucideIcons.checkCircle2,
                                  size: AppIconSizes.m,
                                  color: context.appPalette.accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Password Input
                        AppInput(
                          label: 'Password',
                          placeholder: 'Password',
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          backgroundColor: context.appPalette.muted,
                          validations: InputValidations(
                            required: 'Password is required',
                            validate: (value) {
                              if (value == null || value.isEmpty) return null;
                              if (!isNewUser) return null;
                              final hasUppercase = value.contains(
                                RegExp(r'[A-Z]'),
                              );
                              final hasNumber = value.contains(
                                RegExp(r'[0-9]'),
                              );
                              final hasSpecial = value.contains(
                                RegExp(r'[^A-Za-z0-9]'),
                              );
                              if (value.length < 8 ||
                                  !hasUppercase ||
                                  !hasNumber ||
                                  !hasSpecial) {
                                return 'Password does not meet requirements';
                              }
                              return null;
                            },
                          ),
                          onChanged: (_) => setState(() {}),
                          rightElement: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              color: context.appPalette.mutedForeground,
                              size: AppIconSizes.defaultSize,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (isNewUser) ...[
                          passwordRequirements,
                          const SizedBox(height: 32),
                        ],

                        AppButton(
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          label: 'Log In',
                          onPressed:
                              (_passwordController.text.isEmpty ||
                                  (isNewUser && !passwordRequirements.allMet))
                              ? null
                              : _handleLogin,
                          loadable: !isNewUser,
                        ),
                        const SizedBox(height: 16),
                        if (!isNewUser)
                          TextButton(
                            onPressed: () => context.push(ForgotPasswordScreen.routePath),
                            child: Text(
                              'FORGOT PASSWORD?',
                              style: typography.captionSM,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                  child: Text(
                    'Protected by reCAPTCHA and subject to the Privacy Policy and Terms of Service.',
                    textAlign: TextAlign.center,
                    style: typography.bodySM,
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
