import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';

class PasswordRequirement {
  PasswordRequirement({required this.label, required this.met});
  final String label;
  final bool met;
}

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  List<PasswordRequirement> get requirements => [
    PasswordRequirement(
      label: 'At least 8 characters',
      met: password.length >= 8,
    ),
    PasswordRequirement(
      label: 'One uppercase letter',
      met: password.contains(RegExp(r'[A-Z]')),
    ),
    PasswordRequirement(
      label: 'One number',
      met: password.contains(RegExp(r'[0-9]')),
    ),
    PasswordRequirement(
      label: 'One special character',
      met: password.contains(RegExp(r'[^A-Za-z0-9]')),
    ),
  ];

  bool get allMet => requirements.every((r) => r.met);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: requirements.map((req) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  req.met ? LucideIcons.check : LucideIcons.x,
                  size: 16,
                  color: req.met
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: 12),
                Text(
                  req.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: req.met
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
