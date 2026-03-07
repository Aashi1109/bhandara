import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';
import '../services/secure_storage.dart';
import '../services/local_storage.dart';

import 'explore.dart';
import 'onboarding.dart';
import 'auth.dart';

class SplashScreen extends StatefulWidget {
  static const String routePath = '/';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Ensuring animation shows for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    final authStorage = SecureStorage(namespace: 'auth');
    final userStorage = LocalStorage(namespace: 'user');

    final token = await authStorage.read('token');
    final onboarded = await userStorage.get<bool>('onboarded') ?? false;

    if (!mounted) return;

    if (token != null) {
      if (onboarded) {
        context.go(ExploreScreen.routePath);
      } else {
        context.go(OnboardingScreen.routePath);
      }
    } else {
      // No active session
      if (onboarded) {
        context.go(AuthScreen.routePath);
      } else {
        context.go(OnboardingScreen.routePath);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 90,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -5,
                              color: AppColors.primary,
                            ),
                            children: const [
                              TextSpan(text: 'Foody'),
                              TextSpan(
                                text: '.',
                                style: TextStyle(fontStyle: FontStyle.normal),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'FIND YOUR NEXT MEAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 8,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
