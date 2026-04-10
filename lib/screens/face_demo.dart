import 'package:flutter/material.dart';
import 'package:mobintix_security_suite/mobintix_security_suite.dart';
import 'package:mobintix_ui_kit/mobintix_ui_kit.dart';

import '../services/firebase_backend.dart';

class FaceDemo extends StatefulWidget {
  const FaceDemo({super.key, required this.backend});

  final FirebaseBackend backend;

  @override
  State<FaceDemo> createState() => _FaceDemoState();
}

class _FaceDemoState extends State<FaceDemo> {
  final ValueNotifier<bool> _faceInFrame = ValueNotifier(false);
  final ValueNotifier<Map<String, double>?> _faceLandmarks =
      ValueNotifier(null);
  bool? _registered;
  FaceDetectionStatus _status = FaceDetectionStatus.ready;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  @override
  void dispose() {
    _faceInFrame.dispose();
    _faceLandmarks.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    final reg = await widget.backend.isFaceRegistered();
    if (!mounted) return;
    setState(() => _registered = reg);
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

  /// Waits briefly for a stable face signature from the live camera stream.
  /// Takes several readings and returns the last one, which tends to be
  /// more stable as the face settles in the frame.
  Future<Map<String, double>?> _captureStableSignature() async {
    Map<String, double>? best;
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return null;
      final sig = _faceLandmarks.value;
      if (sig != null && sig.length >= 4) best = Map.of(sig);
    }
    return best;
  }

  Future<void> _register() async {
    if (isFaceMlKitSupported && !_faceInFrame.value) {
      _showResult('Position your face in the oval first.', isError: true);
      return;
    }

    setState(() => _status = FaceDetectionStatus.scanning);
    final signature = await _captureStableSignature();
    if (!mounted) return;

    if (isFaceMlKitSupported && signature == null) {
      _showResult('Could not capture face landmarks. Try again.',
          isError: true);
      setState(() => _status = FaceDetectionStatus.ready);
      return;
    }

    setState(() => _status = FaceDetectionStatus.aligning);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    await widget.backend.registerFace(signature ?? {});
    if (!mounted) return;

    setState(() {
      _status = FaceDetectionStatus.captured;
      _registered = true;
    });
    _showResult('Face registered and saved to Firebase');

    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _status = FaceDetectionStatus.ready);
  }

  Future<void> _authenticate() async {
    if (isFaceMlKitSupported && !_faceInFrame.value) {
      _showResult('Position your face in the oval first.', isError: true);
      return;
    }

    setState(() => _status = FaceDetectionStatus.scanning);
    final signature = await _captureStableSignature();
    if (!mounted) return;

    if (isFaceMlKitSupported && signature == null) {
      _showResult('Could not capture face landmarks. Try again.',
          isError: true);
      setState(() => _status = FaceDetectionStatus.ready);
      return;
    }

    setState(() => _status = FaceDetectionStatus.aligning);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final result = await widget.backend.verifyFace(signature ?? {});
    if (!mounted) return;

    if (result.matched) {
      setState(() => _status = FaceDetectionStatus.captured);
      _showResult(
        'Face verified (distance: ${result.distance.toStringAsFixed(4)})',
      );
    } else {
      setState(() => _status = FaceDetectionStatus.ready);
      _showResult(
        'Face does not match registered face '
        '(distance: ${result.distance.toStringAsFixed(4)})',
        isError: true,
      );
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _status = FaceDetectionStatus.ready);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    if (_registered == null) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    final isRegistered = _registered!;

    return Column(
      children: [
        if (isRegistered)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: spacing.md, vertical: spacing.sm),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(context.appRadius.md),
                border:
                    Border.all(color: colors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: colors.success),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: AppText.bodySmall(
                      'Face registered — verify with the same face to authenticate',
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: FaceDetectionView(
            config: FaceDetectionConfig(
              title: isRegistered ? 'Face Authentication' : 'Face Registration',
              subtitle: isRegistered
                  ? 'Look at the camera to verify your identity.'
                  : 'Position your face in the oval to register.',
              primaryLabel: isRegistered ? 'Verify' : 'Register',
            ),
            cameraPreview: LiveCameraPreview(
              facePresent: _faceInFrame,
              faceLandmarks: _faceLandmarks,
            ),
            status: _status,
            onCapture: isRegistered ? _authenticate : _register,
            onRetry: () async =>
                setState(() => _status = FaceDetectionStatus.ready),
          ),
        ),
      ],
    );
  }
}
