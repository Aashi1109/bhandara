import 'package:flutter/material.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/header.dart';

class DataPrivacyScreen extends StatelessWidget {
  const DataPrivacyScreen({super.key});

  static const String routePath = '/settings/data-privacy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Data & Privacy'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: const [
                _InfoCard(
                  title: 'Location visibility',
                  body:
                      'Your live location is only shared when you explicitly enable it for active events.',
                ),
                SizedBox(height: 16),
                _InfoCard(
                  title: 'Account data',
                  body:
                      'Your profile, interests, and participation history stay attached to your account so your event experience remains personalized.',
                ),
                SizedBox(height: 16),
                _InfoCard(
                  title: 'Media handling',
                  body:
                      'Profile photos and event media are stored separately from core account data so they can be updated or removed independently.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appPalette.muted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            title,
            style: typography.titleSM.copyWith(color: context.appPalette.primary),
          ),
          Text(
            body,
            style: typography.bodyBase.copyWith(
              height: 1.5,
              color: context.appPalette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
