import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/user.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/input.dart';
import '../../widgets/settings_action_footer.dart';
import '../../widgets/snackbar.dart';
import '../settings.dart';

class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  static const String routePath = '/settings/email';

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _didHydrate = false;
  String _initialEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final typography = context.appTypography;
    if (!_didHydrate && user != null) {
      _emailController.text = user.email;
      _initialEmail = user.email;
      _didHydrate = true;
    }

    final isDirty = _emailController.text.trim() != _initialEmail.trim();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Edit Email',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.muted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.mail,
                        size: AppIconSizes.xl,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Email Address', style: typography.heading3),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${user?.email ?? ''}',
                      style: typography.bodyMD,
                    ),
                    const SizedBox(height: 48),
                    AppInput(
                      type: AppInputType.email,
                      label: null,
                      placeholder: 'Enter new email address',
                      borderRadius: 16,
                      controller: _emailController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SettingsActionFooter(
            label: 'Save Changes',
            onPressed: isDirty
                ? () {
                    AppSnackBar.show(
                      context,
                      message: 'Email updates are not available yet.',
                      type: SnackBarType.warning,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
