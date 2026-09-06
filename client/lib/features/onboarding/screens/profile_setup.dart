import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/providers/auth.dart';
import '../../../../../shared/providers/login_flow.dart';
import './preferences.dart';
import '../../../../../shared/widgets/snackbar.dart';
import '../../../shared/utils/error.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/tabs.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  static const String routePath = '/profile-setup';

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  String _gender = 'male';
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final flowState = ref.read(loginFlowProvider);

    final email = flowState.data['email'];
    final password = flowState.data['password'];

    try {
      await ref.read(authProvider.notifier).signup({
        'name': name,
        'gender': _gender,
        'email': email,
        'password': password,
      });

      if (!mounted) return;
      ref.read(loginFlowProvider.notifier).clear();
      context.go(PreferencesScreen.routePath);
    } catch (e) {
      if (!mounted) return;
      final message = extractExceptionMessage(e);
      debugPrint(message);
      AppSnackBar.show(context, message: message, type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final typography = context.appTypography;

    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Stack(
        children: [
          // Decorative Blurs (Simulated)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: context.appPalette.muted.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: context.appPalette.muted.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            children: [
              AppHeader(
                onBack: () => context.pop(),
                title: 'Set Up Profile',
                showBorder: false,
                backgroundColor: context.appPalette.transparent,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Avatar Section
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.appPalette.muted.withValues(alpha: 0.1),
                                  width: 4,
                                ),
                              ),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: context.appPalette.muted,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.appPalette.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.appPalette.surface,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  LucideIcons.camera,
                                  size: AppIconSizes.m,
                                  color: context.appPalette.surface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Upload Photo',
                        style: typography.heading3Heavy.copyWith(
                          color: context.appPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Personalize your profile',
                        style: typography.bodyMDSemi.copyWith(
                          color: context.appPalette.mutedForeground,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Form Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'FULL NAME',
                              style: typography.overlineStrong.copyWith(
                                color: context.appPalette.mutedForeground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppInput(
                            controller: _nameController,
                            placeholder: 'John Doe',
                            borderRadius: 20,
                            backgroundColor: context.appPalette.surface,
                            hasBorder: true,
                            validations: const InputValidations(
                              required: true,
                              minLength: 5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'GENDER',
                              style: typography.overlineStrong.copyWith(
                                color: context.appPalette.mutedForeground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppTabs<String>(
                            currentValue: _gender,
                            onChanged: (value) =>
                                setState(() => _gender = value),
                            items: const [
                              AppTabItem(
                                label: 'Male',
                                value: 'male',
                                icon: '♂',
                              ),
                              AppTabItem(
                                label: 'Female',
                                value: 'female',
                                icon: '♀',
                              ),
                              AppTabItem(
                                label: 'Other',
                                value: 'other',
                                icon: '⋯',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 120), // Bottom padding for button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Action
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: context.appPalette.surface.withValues(alpha: 0.8),
                border: Border(top: BorderSide(color: context.appPalette.border)),
              ),
              child: AppButton(
                size: AppButtonSize.xl,
                fullWidth: true,
                label: 'Continue',
                isLoading: isLoading,
                onPressed: isLoading ? null : _handleContinue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
