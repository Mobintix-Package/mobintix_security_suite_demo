import 'package:flutter/material.dart';
import 'package:mobintix_security_suite/mobintix_security_suite.dart';
import 'package:mobintix_ui_kit/mobintix_ui_kit.dart';

import '../services/firebase_backend.dart';

class OtpDemo extends StatefulWidget {
  const OtpDemo({super.key, required this.backend});

  final FirebaseBackend backend;

  @override
  State<OtpDemo> createState() => _OtpDemoState();
}

class _OtpDemoState extends State<OtpDemo> {
  String? _currentCode;
  bool _sending = false;
  bool _verified = false;
  int _viewKey = 0;

  void _showResult(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? colors.error : null,
    ));
  }

  Future<void> _sendOtp() async {
    setState(() => _sending = true);
    final code = await widget.backend.generateOtp();
    if (!mounted) return;
    setState(() {
      _currentCode = code;
      _sending = false;
      _verified = false;
      _viewKey++;
    });
  }

  Future<void> _onComplete(String otp) async {
    final ok = await widget.backend.verifyOtp(otp);
    if (!mounted) return;
    if (ok) {
      setState(() => _verified = true);
      _showResult('OTP verified — matches Firebase record');
    } else {
      _showResult('OTP invalid or expired', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    if (_currentCode == null) {
      return _SendOtpView(
        sending: _sending,
        onSend: _sendOtp,
      );
    }

    if (_verified) {
      return _VerifiedView(onReset: () {
        setState(() {
          _currentCode = null;
          _verified = false;
        });
      });
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
          padding: EdgeInsets.symmetric(
              horizontal: spacing.md, vertical: spacing.sm),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(context.appRadius.md),
            border:
                Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.sms_outlined, size: 20, color: colors.primary),
              SizedBox(width: spacing.sm),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textSecondary),
                    children: [
                      const TextSpan(text: 'SMS received: '),
                      TextSpan(
                        text: _currentCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          letterSpacing: 2,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: OtpView(
            key: ValueKey('otp_$_viewKey'),
            config: const OtpConfig(
              otpLength: 6,
              subtitle: 'Enter the 6-digit code shown above.',
              cooldownEscalation: [
                Duration(seconds: 30),
                Duration(seconds: 60),
                Duration(seconds: 120),
              ],
            ),
            onComplete: _onComplete,
            onResend: () async {
              await _sendOtp();
              _showResult('New OTP generated and stored in Firebase');
            },
          ),
        ),
      ],
    );
  }
}

class _SendOtpView extends StatelessWidget {
  const _SendOtpView({required this.sending, required this.onSend});

  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.sms_outlined, size: 56, color: colors.primary),
          ),
          SizedBox(height: spacing.xl),
          AppText.headlineMedium(
            'OTP Verification',
            textAlign: TextAlign.center,
          ),
          const VSpace.sm(),
          AppText.bodyMedium(
            'Tap below to generate a one-time code. '
            'The code is stored in Firebase and shown on screen '
            '(simulating an SMS).',
            textAlign: TextAlign.center,
            color: colors.textSecondary,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: 'Send OTP',
              leadingIcon: Icons.send_rounded,
              isFullWidth: true,
              isLoading: sending,
              onPressed: onSend,
            ),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        children: [
          const Spacer(flex: 2),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.success.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.check_circle_rounded,
                  size: 52, color: colors.success),
            ),
          ),
          SizedBox(height: spacing.xl),
          AppText.headlineMedium('Verified', textAlign: TextAlign.center),
          const VSpace.sm(),
          AppText.bodyMedium(
            'OTP matched the Firebase record successfully.',
            textAlign: TextAlign.center,
            color: colors.textSecondary,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: 'Try Again',
              isFullWidth: true,
              onPressed: onReset,
            ),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }
}
