import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/utils/error.dart';
import '../services/auth.dart';

import './reset_password.dart';

class ForgotPasswordOTPScreen extends StatefulWidget {
  const ForgotPasswordOTPScreen({super.key, this.email});

  static const String routePath = '/forgot-password/otp';

  final String? email;

  @override
  State<ForgotPasswordOTPScreen> createState() =>
      _ForgotPasswordOTPScreenState();
}

class _ForgotPasswordOTPScreenState extends State<ForgotPasswordOTPScreen> {
  static const int _codeLength = 6;
  static const int _resendCooldownSeconds = 60;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  int _secondsRemaining = _resendCooldownSeconds;
  Timer? _resendTimer;

  bool get _isCodeComplete => _controllers.every((c) => c.text.isNotEmpty);
  bool get _canResend => _secondsRemaining == 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onPaste(String digits) {
    for (var i = 0; i < _codeLength && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    final nextIndex =
        digits.length < _codeLength ? digits.length : _codeLength - 1;
    _focusNodes[nextIndex].requestFocus();
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  Future<void> _handleVerify() async {
    final code = _controllers.map((c) => c.text).join();
    try {
      final token = await authService.verifyPasswordResetOTP(
        widget.email ?? '',
        code,
      );
      if (mounted) {
        unawaited(
          context.push(
            ResetPasswordScreen.routePath,
            extra: {'token': token, 'email': widget.email},
          ),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, extractExceptionMessage(e));
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;
    try {
      await authService.sendPasswordResetEmail(widget.email ?? '');
      if (mounted) {
        AppSnackBar.success(context, 'Reset code sent again');
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, extractExceptionMessage(e));
    }
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return email;
    final masked =
        '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    return '$masked@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final maskedEmail = _maskEmail(widget.email ?? '');

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppHeader(
                  onBack: () => context.pop(),
                  title: '',
                  showBorder: false,
                  backgroundColor: AppColors.transparent,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 72,
                          height: 72,
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
                        Text('Check your email', style: typography.heading2),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: typography.bodyLG.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'We\'ve sent a 6-digit verification code to ',
                                ),
                                TextSpan(
                                  text: maskedEmail,
                                  style: typography.bodyMDStrong.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'VERIFICATION CODE',
                                  style: typography.overline.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(_codeLength, (index) {
                                  return _OTPDigitBox(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    onChanged: (value) =>
                                        _onDigitChanged(index, value),
                                    onKeyEvent: (event) =>
                                        _onKeyEvent(index, event),
                                    onPaste: _onPaste,
                                  );
                                }),
                              ),
                              const SizedBox(height: 24),
                              AppButton(
                                size: AppButtonSize.lg,
                                fullWidth: true,
                                label: 'Verify Code',
                                loadable: true,
                                iconRight: const Icon(LucideIcons.arrowRight),
                                onPressed:
                                    _isCodeComplete ? _handleVerify : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ResendRow(
                          canResend: _canResend,
                          secondsRemaining: _secondsRemaining,
                          onResend: _handleResend,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.canResend,
    required this.secondsRemaining,
    required this.onResend,
  });

  final bool canResend;
  final int secondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Didn\'t receive the code? ',
          style: typography.bodyMD.copyWith(color: AppColors.mutedForeground),
        ),
        if (canResend)
          GestureDetector(
            onTap: onResend,
            child: Text(
              'Resend code',
              style: typography.bodyMDStrong.copyWith(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        else
          Text(
            'Resend in ${secondsRemaining}s',
            style: typography.bodyMDStrong.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
      ],
    );
  }
}

/// Restricts the box to a single digit and intercepts paste to distribute
/// across all OTP boxes via [onPaste].
class _SingleDigitFormatter extends TextInputFormatter {
  const _SingleDigitFormatter({required this.onPaste});

  final void Function(String digits) onPaste;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 1) {
      // Paste detected — distribute after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) => onPaste(digits));
      return oldValue.copyWith(
        text: digits[0],
        selection: const TextSelection.collapsed(offset: 1),
      );
    }
    final single = digits.isEmpty ? '' : digits[0];
    return newValue.copyWith(
      text: single,
      selection: TextSelection.collapsed(offset: single.length),
    );
  }
}

class _OTPDigitBox extends StatelessWidget {
  const _OTPDigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
    required this.onPaste,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;
  final void Function(String digits) onPaste;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: 44,
        height: 56,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [_SingleDigitFormatter(onPaste: onPaste)],
          style: typography.titleLG.copyWith(color: AppColors.primary),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
