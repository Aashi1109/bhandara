import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';
import '../services/secure_storage.dart';
import '../services/local_storage.dart';
import '../services/auth.dart';
import '../providers/user.dart';
import '../utils/auth_redirect.dart';

import 'onboarding.dart';
import 'auth.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const String routePath = '/';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isCheckingSession = true;

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
    final authStorage = SecureStorage(namespace: 'auth');
    final userStorage = LocalStorage(namespace: 'user');

    final token = await authStorage.read('token');
    final onboarded = await userStorage.get<bool>('onboarded') ?? false;

    if (!mounted) return;

    if (token != null) {
      try {
        final user = await authService.getSession();

        if (!mounted) return;

        if (user != null) {
          ref.read(userProfileProvider.notifier).setUser(user);
          // Socket session is started by AppSessionCoordinator when user state changes.
          if (!mounted) return;
          context.go(routeForAuthenticatedUser(user));
        } else {
          ref.read(userProfileProvider.notifier).setUser(null);
          await authService.logout();
          if (!mounted) return;
          context.go(AuthScreen.routePath);
        }
      } catch (_) {
        // Invalid session
        ref.read(userProfileProvider.notifier).setUser(null);
        await authService.logout();
        if (!mounted) return;
        context.go(AuthScreen.routePath);
      }
    } else {
      // No active session
      ref.read(userProfileProvider.notifier).setUser(null);
      if (!mounted) return;
      if (onboarded) {
        context.go(AuthScreen.routePath);
      } else {
        context.go(OnboardingScreen.routePath);
      }
    }

    if (mounted) {
      setState(() => _isCheckingSession = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
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
                      spacing: 8,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: typography.displayXL,
                            children: const [
                              TextSpan(text: 'Foody'),
                              TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        Text(
                          'FIND YOUR NEXT MEAL',
                          style: typography.captionSM,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SafeArea(
              top: false,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isCheckingSession ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
