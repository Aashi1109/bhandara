import 'package:flutter/material.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/header.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static const String routePath = '/settings/about';

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          const AppHeader(title: 'About App'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.appPalette.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.appPalette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foody', style: typography.heading3),
                    const SizedBox(height: 8),
                    Text('Version 2.4.0', style: typography.captionMD),
                    const SizedBox(height: 20),
                    Text(
                      'Foody helps people discover food events, join conversations around them, and track what matters after the event is live.',
                      style: typography.bodyMD,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
