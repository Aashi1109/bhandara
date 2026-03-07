import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../services/local_storage.dart';

class OnboardingScreen extends StatefulWidget {
  static const String routePath = '/onboarding';
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _current = 0;
  final storage = LocalStorage(namespace: 'user');

  void _finish() async {
    await storage.set('onboarded', true);
    widget.onComplete();
  }

  final _slides = const [
    _OnboardingSlide(
      title: 'Find Free Food',
      description:
          'Discover hidden gems and ongoing events sharing free meals in your local neighborhood.',
      icon: LucideIcons.mapPin,
    ),
    _OnboardingSlide(
      title: 'Share with Others',
      description:
          'Help your community by sharing live food events you encounter in real-time.',
      icon: LucideIcons.heart,
    ),
    _OnboardingSlide(
      title: 'Join the Community',
      description:
          'Connect with neighbors and build a stronger, more sustainable network together.',
      icon: LucideIcons.users,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Skip button
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onTap: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildSlide(_slides[_current]),
            ),
          ),

          // Dots + Button
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _current ? 32 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? AppColors.primary
                            : AppColors.muted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Button
                AppButton(
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  label: _current == 2 ? 'Get Started' : 'Continue',
                  iconRight: const Icon(LucideIcons.chevronRight),
                  onPressed: () {
                    if (_current < 2) {
                      setState(() => _current++);
                    } else {
                      _finish();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Column(
      key: ValueKey(slide.title),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 192,
          height: 192,
          decoration: const BoxDecoration(
            color: AppColors.muted,
            shape: BoxShape.circle,
          ),
          child: Icon(slide.icon, size: 80, color: AppColors.primary),
        ),
        const SizedBox(height: 40),
        Text(
          slide.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;

  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
  });
}
