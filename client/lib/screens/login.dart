import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/login_flow.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/input.dart';
import '../widgets/header.dart';
import '../providers/auth.dart';
import '../widgets/snackbar.dart';

import 'auth.dart';
import 'profile_setup.dart';
import 'explore.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.extra});
  static const String routePath = '/login';
  final Map<String, dynamic>? extra;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showPassword = false;
  bool _isLoading = false;
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
        setState(() => _isLoading = true);

        if (isNewUser) {
          ref.read(loginFlowProvider.notifier).update({
            'password': _passwordController.text,
          });
          await context.push(ProfileSetupScreen.routePath);
          return;
        }

        // Strictly using login as requested, even for new users
        final response = await ref
            .read(authProvider.notifier)
            .login(email, _passwordController.text);

        if (!mounted) return;
        if (response.error != null) {
          AppSnackBar.show(
            context,
            message: response.error!,
            type: SnackBarType.error,
          );
        } else {
          await context.push(ExploreScreen.routePath);
          ref.invalidate(loginFlowProvider);
        }
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: 'An unexpected error occurred',
          type: SnackBarType.error,
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordController.text;
    final requirements = [
      {'label': 'At least 8 characters', 'met': password.length >= 8},
      {
        'label': 'One uppercase letter',
        'met': password.contains(RegExp(r'[A-Z]')),
      },
      {'label': 'One number', 'met': password.contains(RegExp(r'[0-9]'))},
      {
        'label': 'One special character',
        'met': password.contains(RegExp(r'[^A-Za-z0-9]')),
      },
    ];

    final email = ref.watch(loginFlowProvider).email ?? 'User';
    final initial = email.isNotEmpty && email != 'User'
        ? email[0].toUpperCase()
        : 'U';
    debugPrint('email: ${ref.watch(loginFlowProvider)}');

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                        const SizedBox(height: 32),
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your password to continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // User Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: AppColors.surface,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  ref.watch(loginFlowProvider).email ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  LucideIcons.checkCircle2,
                                  size: 16,
                                  color: AppColors.accent,
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
                          backgroundColor: AppColors.muted,
                          validations: InputValidations(
                            required: 'Password is required',
                            validate: (value) {
                              if (value == null || value.isEmpty) return null;
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
                              color: AppColors.mutedForeground,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Validation Rows
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: requirements.map((req) {
                              final met = req['met']! as bool;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      met ? LucideIcons.check : LucideIcons.x,
                                      size: 16,
                                      color: met
                                          ? AppColors.primary
                                          : AppColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      req['label']! as String,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: met
                                            ? AppColors.primary
                                            : AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        AppButton(
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          label: 'Log In',
                          isLoading: _isLoading,
                          iconRight: _isLoading
                              ? null
                              : const Icon(LucideIcons.arrowRight),
                          onPressed:
                              (_isLoading ||
                                  _passwordController.text.isEmpty ||
                                  !requirements.every((r) => r['met']! as bool))
                              ? null
                              : _handleLogin,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'FORGOT PASSWORD?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(40, 0, 40, 24),
                  child: Text(
                    'Protected by reCAPTCHA and subject to the Privacy Policy and Terms of Service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                      height: 1.5,
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
