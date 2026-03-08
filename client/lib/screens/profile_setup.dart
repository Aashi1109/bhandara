import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foody_mobile/providers/auth.dart';
import 'package:foody_mobile/providers/login_flow.dart';
import 'package:foody_mobile/screens/preferences.dart';
import 'package:foody_mobile/widgets/snackbar.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/input.dart';
import '../widgets/header.dart';
import '../widgets/tabs.dart';

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

    final response = await ref.read(authProvider.notifier).signup({
      'name': name,
      'gender': _gender,
      'email': email,
      'password': password,
    });

    if (!mounted) return;

    if (response.error != null) {
      debugPrint(response.error);
      AppSnackBar.show(
        context,
        message: response.error!,
        type: SnackBarType.error,
      );
      return;
    }

    ref.read(loginFlowProvider.notifier).clear();

    // Handle profile setup completion
    await context.push(PreferencesScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.surface,
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
                color: AppColors.muted.withValues(alpha: 0.2),
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
                color: AppColors.muted.withValues(alpha: 0.2),
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
                backgroundColor: AppColors.transparent,
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
                                  color: AppColors.muted.withValues(alpha: 0.1),
                                  width: 4,
                                ),
                              ),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFDE6D8),
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
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
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
                                child: const Icon(
                                  LucideIcons.camera,
                                  size: 16,
                                  color: AppColors.surface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Upload Photo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Personalize your profile',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Form Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'FULL NAME',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppInput(
                            controller: _nameController,
                            placeholder: 'John Doe',
                            height: 64,
                            borderRadius: 20,
                            backgroundColor: AppColors.surface,
                            hasBorder: true,
                            validations: const InputValidations(
                              required: true,
                              minLength: 5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'GENDER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: AppColors.mutedForeground,
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
                color: AppColors.surface.withValues(alpha: 0.8),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(
                size: AppButtonSize.xl,
                fullWidth: true,
                label: 'Continue',
                isLoading: isLoading,
                iconRight: isLoading
                    ? null
                    : const Icon(LucideIcons.arrowRight),
                onPressed: isLoading ? null : _handleContinue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
