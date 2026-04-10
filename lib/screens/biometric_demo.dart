import 'package:flutter/material.dart';
import 'package:mobintix_security_suite/mobintix_security_suite.dart';
import 'package:mobintix_ui_kit/mobintix_ui_kit.dart';

import '../services/firebase_backend.dart';

class BiometricDemo extends StatefulWidget {
  const BiometricDemo({super.key, required this.backend});

  final FirebaseBackend backend;

  @override
  State<BiometricDemo> createState() => _BiometricDemoState();
}

class _BiometricDemoState extends State<BiometricDemo> {
  bool? _enrolled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkEnrollment();
  }

  Future<void> _checkEnrollment() async {
    final enrolled = await widget.backend.isBiometricEnrolled();
    if (!mounted) return;
    setState(() => _enrolled = enrolled);
  }

  void _showResult(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? colors.error : null,
    ));
  }

  Future<bool> _runSystemBiometric(String reason) async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      if (!canCheck && !supported) {
        _showResult('No biometrics available on this device.', isError: true);
        return false;
      }
      return await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      if (mounted) _showResult('Biometric error: $e', isError: true);
      return false;
    }
  }

  Future<void> _enroll() async {
    if (_busy) return;
    setState(() => _busy = true);

    final ok = await _runSystemBiometric('Enroll your biometric');
    if (!mounted) return;

    if (ok) {
      await widget.backend.enrollBiometric();
      if (!mounted) return;
      setState(() => _enrolled = true);
      _showResultSheet(
        success: true,
        title: 'Enrolled',
        message: 'Biometric enrolled and saved to Firebase.',
      );
    } else {
      _showResultSheet(
        success: false,
        title: 'Enrollment Failed',
        message: 'System biometric was not completed.',
      );
    }

    setState(() => _busy = false);
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    setState(() => _busy = true);

    final ok = await _runSystemBiometric('Verify your identity');
    if (!mounted) return;

    if (ok) {
      await widget.backend.recordBiometricAuth();
      if (!mounted) return;
      _showResultSheet(
        success: true,
        title: 'Verified',
        message: 'Biometric matched — authentication recorded in Firebase.',
      );
    } else {
      _showResultSheet(
        success: false,
        title: 'Not Verified',
        message: 'Biometric verification was not completed.',
      );
    }

    setState(() => _busy = false);
  }

  void _showResultSheet({
    required bool success,
    required String title,
    required String message,
  }) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final radius = context.appRadius;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            spacing.lg, spacing.lg, spacing.lg, spacing.xl + spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: spacing.xl),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (success ? colors.success : colors.error)
                      .withValues(alpha: 0.12),
                ),
                child: Icon(
                  success
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 44,
                  color: success ? colors.success : colors.error,
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
            AppText.titleMedium(title,
                fontWeight: FontWeight.w700, textAlign: TextAlign.center),
            const VSpace.xs(),
            AppText.bodySmall(message,
                textAlign: TextAlign.center, color: colors.textSecondary),
            SizedBox(height: spacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                text: 'Done',
                isFullWidth: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    if (_enrolled == null) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    final isEnrolled = _enrolled!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        children: [
          if (isEnrolled)
            Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: spacing.md, vertical: spacing.sm),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(context.appRadius.md),
                  border: Border.all(
                      color: colors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: colors.success),
                    SizedBox(width: spacing.sm),
                    AppText.bodySmall('Biometric enrolled in Firebase',
                        color: colors.success),
                  ],
                ),
              ),
            ),
          const Spacer(flex: 2),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.fingerprint, size: 56, color: colors.primary),
          ),
          SizedBox(height: spacing.xl),
          AppText.headlineMedium(
            isEnrolled ? 'Authenticate' : 'Enroll Biometric',
            textAlign: TextAlign.center,
          ),
          const VSpace.sm(),
          AppText.bodyMedium(
            isEnrolled
                ? 'Your biometric is registered. Tap below to verify.'
                : 'Register your fingerprint or Face ID. '
                    'This saves enrollment status to Firebase.',
            textAlign: TextAlign.center,
            color: colors.textSecondary,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: isEnrolled ? 'Authenticate' : 'Enroll',
              leadingIcon: Icons.fingerprint,
              isFullWidth: true,
              isLoading: _busy,
              onPressed: isEnrolled ? _authenticate : _enroll,
            ),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }
}
