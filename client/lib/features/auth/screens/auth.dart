import 'dart:async';

import 'package:flutter/material.dart';
import '../../profile/models/user.dart';
import '../../profile/services/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/login_flow.dart';
import '../../../shared/providers/auth.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/utils/auth_redirect.dart';
import '../../../shared/utils/error.dart';

import './login.dart';

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
    try {
      bool isUserExists = false;
      bool isSocialLogin = false;
      User? user;
      final users = await userService.getByQuery(email: _emailController.text);
      final items = users.items;
      if (items.isNotEmpty) {
        isUserExists = true;
        isSocialLogin = items.first.isSocialLogin;
        user = items.first;
      }
      ref.read(loginFlowProvider.notifier).replace({
        ...?user?.toJson(),
        'email': _emailController.text,
      });
      if (mounted) {
        if (isUserExists) {
          if (!isSocialLogin) {
            unawaited(context.push(LoginScreen.routePath));
          } else {
            AppSnackBar.warning(context, 'Please login using social login');
          }
        } else {
          unawaited(context.push(LoginScreen.routePath));
        }
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, extractExceptionMessage(e));
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
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
                    Text('Taste the\nNeighborhood', style: typography.heading1),
                    const SizedBox(height: 16),
                    Text(
                      'Join the exclusive community finding the best free food events near you.',
                      style: typography.bodyLG,
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
                            type: AppInputType.email,
                            label: 'Email',
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
                            label: 'Continue',
                            loadable: true,
                            iconRight: const Icon(LucideIcons.arrowRight),
                            onPressed: _isEmailValid ? _handleContinue : null,
                          ),

                          // Divider
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Divider(color: AppColors.border),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'OR CONNECT WITH',
                                    style: typography.overline,
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(color: AppColors.border),
                                ),
                              ],
                            ),
                          ),

                          // Social buttons
                          AppButton(
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.lg,
                            fullWidth: true,
                            onPressed: () async {
                              try {
                                final user = await ref
                                    .read(authProvider.notifier)
                                    .signInWithGoogle();
                                if (context.mounted) {
                                  context.go(routeForAuthenticatedUser(user));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  final message = extractExceptionMessage(e);
                                  AppSnackBar.show(
                                    context,
                                    message: message,
                                    type: SnackBarType.error,
                                  );
                                }
                              }
                            },
                            child: SvgPicture.asset(
                              'assets/svg/google_logo.svg',
                              width: 20,
                              height: 20,
                            ),
                          ),
                          // TODO: Re-enable Apple Sign-In when iOS support is ready
                          // const SizedBox(width: 16),
                          // const Expanded(
                          //   child: AppButton(
                          //     variant: AppButtonVariant.outline,
                          //     size: AppButtonSize.lg,
                          //     child: Icon(
                          //       LucideIcons.apple,
                          //       size: AppIconSizes.defaultSize,
                          //       color: AppColors.primary,
                          //     ),
                          //   ),
                          // ),
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
                                size: AppIconSizes.defaultSize,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Near Me Mode',
                                    style: typography.labelMD,
                                  ),
                                  Text(
                                    'Show events within 5km radius',
                                    style: typography.bodySM,
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
                        text: TextSpan(
                          style: typography.bodySM,
                          children: [
                            const TextSpan(
                              text: 'By joining, you agree to our ',
                            ),
                            TextSpan(
                              text: 'Terms',
                              style: typography.bodySM.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' & '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: typography.bodySM.copyWith(
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
