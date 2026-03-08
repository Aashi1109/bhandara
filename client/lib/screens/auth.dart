import 'package:flutter/material.dart';
import 'package:foody_mobile/models/user.dart';
import 'package:foody_mobile/services/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/login_flow.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/input.dart';
import '../widgets/card.dart';
import '../widgets/header.dart';
import '../widgets/snackbar.dart';

import '../services/auth.dart';

import 'login.dart';
import 'explore.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  static const String routePath = '/auth';

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool nearMe = true;
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailValid = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    bool isUserExists = false;
    bool isSocialLogin = false;
    User? user;
    // check if user exists with email
    try {
      final users = await userService.getByQuery(email: _emailController.text);
      final items = users.data?.items;
      if (items != null && items.isNotEmpty) {
        isUserExists = true;
        isSocialLogin = items.first.isSocialLogin;
        user = items.first;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    if (mounted) {
      if (isUserExists) {
        if (!isSocialLogin) {
          await context.push(LoginScreen.routePath);
        } else {
          AppSnackBar.show(
            context,
            message: 'Please login using social login',
            type: SnackBarType.warning,
          );
        }
      } else {
        ref.read(loginFlowProvider.notifier).update({
          'email': _emailController.text,
          ...?user?.toJson(),
        });
        await context.push(LoginScreen.routePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taste the\nNeighborhood',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Join the exclusive community finding the best free food events near you.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Email card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Column(
                        children: [
                          AppInput(
                            label: 'Email',
                            placeholder: 'chef@foodie.com',
                            keyboardType: TextInputType.emailAddress,
                            controller: _emailController,
                            validations: InputValidations(
                              required: 'Email is required',
                              pattern: ValidationRule(
                                value: RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ),
                                message: 'Invalid email address',
                              ),
                            ),
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
                            label: 'Continue',
                            iconRight: const Icon(LucideIcons.arrowRight),
                            onPressed: _isEmailValid ? _handleContinue : null,
                          ),

                          // Divider
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(color: AppColors.border),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR CONNECT WITH',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: AppColors.border),
                                ),
                              ],
                            ),
                          ),

                          // Social buttons
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  variant: AppButtonVariant.outline,
                                  size: AppButtonSize.lg,
                                  onPressed: () async {
                                    final response = await authService
                                        .signInWithGoogle();
                                    if (context.mounted) {
                                      if (response.data != null) {
                                        context.go(ExploreScreen.routePath);
                                      } else {
                                        AppSnackBar.show(
                                          context,
                                          message:
                                              response.error ??
                                              'Google Sign-In failed',
                                          type: SnackBarType.error,
                                        );
                                      }
                                    }
                                  },
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          'https://picsum.photos/seed/google/24/24',
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: AppButton(
                                  variant: AppButtonVariant.outline,
                                  size: AppButtonSize.lg,
                                  child: Icon(
                                    LucideIcons.apple,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Near Me toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: AppCard(
                        borderRadius: 28,
                        padding: AppCardPadding.sm,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.muted,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.locateFixed,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Near Me Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Show events within 5km radius',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => nearMe = !nearMe),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 48,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: nearMe
                                      ? AppColors.primary
                                      : AppColors.muted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 300),
                                  alignment: nearMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
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
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Footer
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                          ),
                          children: [
                            TextSpan(text: 'By joining, you agree to our '),
                            TextSpan(
                              text: 'Terms',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: ' & '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
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
    );
  }
}
