import 'package:flutter/material.dart';
import 'package:mobintix_security_suite/mobintix_security_suite.dart';
import 'package:mobintix_ui_kit/mobintix_ui_kit.dart';

import '../services/firebase_backend.dart';

class MpinDemo extends StatefulWidget {
  const MpinDemo({super.key, required this.backend});

  final FirebaseBackend backend;

  @override
  State<MpinDemo> createState() => _MpinDemoState();
}

class _MpinDemoState extends State<MpinDemo> {
  bool? _hasPin;
  bool _isCreate = true;
  int _viewKey = 0;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final exists = await widget.backend.isMpinCreated();
    if (!mounted) return;
    setState(() {
      _hasPin = exists;
      _isCreate = !exists;
    });
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

  Future<void> _onComplete(String pin) async {
    if (_isCreate) {
      await widget.backend.createMpin(pin);
      _showResult('MPIN created and stored in Firebase');
      setState(() {
        _hasPin = true;
        _isCreate = false;
        _viewKey++;
      });
    } else {
      final ok = await widget.backend.verifyMpin(pin);
      if (!mounted) return;
      if (ok) {
        _showResult('MPIN verified successfully');
      } else {
        _showResult('Wrong MPIN — does not match', isError: true);
      }
      setState(() => _viewKey++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    if (_hasPin == null) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: spacing.lg, vertical: spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Create PIN')),
                    ButtonSegment(value: false, label: Text('Verify PIN')),
                  ],
                  selected: {_isCreate},
                  onSelectionChanged: (v) {
                    setState(() {
                      _isCreate = v.first;
                      _viewKey++;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: colors.surface,
                    selectedBackgroundColor:
                        colors.primary.withValues(alpha: 0.12),
                    selectedForegroundColor: colors.primary,
                  ),
                ),
              ),
              if (_hasPin!) ...[
                SizedBox(width: spacing.xs),
                Tooltip(
                  message: 'PIN exists in Firebase',
                  child: Icon(Icons.check_circle,
                      color: colors.success, size: 22),
                ),
              ],
            ],
          ),
        ),
        if (!_isCreate && !_hasPin!)
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 48, color: colors.textSecondary),
                    SizedBox(height: spacing.md),
                    AppText.titleSmall(
                      'No MPIN yet',
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w600,
                    ),
                    const VSpace.xs(),
                    AppText.bodySmall(
                      'Switch to "Create PIN" first to store one in Firebase.',
                      textAlign: TextAlign.center,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: MpinView(
              key: ValueKey('mpin_${_isCreate}_$_viewKey'),
              config: MpinConfig(isCreate: _isCreate, mpinLength: 4),
              onComplete: _onComplete,
              onForgotPin: () async =>
                  _showResult('Contact support to reset your MPIN.'),
            ),
          ),
      ],
    );
  }
}
