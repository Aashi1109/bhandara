import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/header.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const String routePath = '/settings/help-support';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Help & Support'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: const [
                _FaqItem(
                  question: 'How do I join an event?',
                  answer:
                      'Open an event from Explore or Search, then use the join action on the event details screen.',
                ),
                SizedBox(height: 12),
                _FaqItem(
                  question: 'How do I manage my event preferences?',
                  answer:
                      'Use Settings to update cuisines, notifications, location defaults, and profile details.',
                ),
                SizedBox(height: 12),
                _FaqItem(
                  question: 'Why am I seeing updates?',
                  answer:
                      'Updates reflect activity related to your events, messages, and achievements so you can jump back into relevant activity.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
