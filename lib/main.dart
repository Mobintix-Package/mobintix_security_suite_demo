import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mobintix_security_suite/mobintix_security_suite.dart';
import 'package:mobintix_ui_kit/mobintix_ui_kit.dart';

import 'firebase_options.dart';
import 'screens/biometric_demo.dart';
import 'screens/face_demo.dart';
import 'screens/mpin_demo.dart';
import 'screens/otp_demo.dart';
import 'services/firebase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const DemoApp());
}

/// Maps [AppTheme] into [SecuritySuiteTheme] for MPIN / OTP / biometric / face.
ThemeData demoMaterialTheme(AppTheme appTheme) {
  final c = appTheme.colors;
  return appTheme.toThemeData().copyWith(
        extensions: <ThemeExtension<dynamic>>[
          SecuritySuiteTheme(
            pinActiveColor: c.primary,
            pinErrorColor: c.error,
            timerActiveColor: c.primary,
            timerUrgentColor: c.error,
            timerTrackColor: c.border,
            scanRingColor: c.primary,
            badgeColor: c.success,
            faceGuideColor: c.primary,
            faceOverlayColor: appTheme.isDark
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.black.withValues(alpha: 0.54),
            cameraPlaceholderColor: c.surface,
            cameraLiveIndicatorColor: c.error,
            cameraFaceDetectedColor: c.success,
            cameraFaceMissingColor: c.textSecondary,
            cameraOverlayTextColor:
                appTheme.isDark ? c.textPrimary : Colors.white,
            processingOverlayColor:
                Colors.black.withValues(alpha: appTheme.isDark ? 0.55 : 0.45),
            successCheckColor: c.success,
          ),
        ],
      );
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  AppTheme _theme = AppTheme.light();
  int _index = 0;

  late final FirebaseBackend _backend = FirebaseBackend();

  void _toggleTheme() {
    setState(() {
      _theme = _theme.isDark ? AppTheme.light() : AppTheme.dark();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      theme: _theme,
      child: MaterialApp(
        title: 'Mobintix Security Suite Demo',
        debugShowCheckedModeBanner: false,
        theme: demoMaterialTheme(_theme),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Security Suite Demo'),
            actions: [
              IconButton(
                tooltip: 'Toggle theme',
                onPressed: _toggleTheme,
                icon: Icon(
                  _theme.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              MpinDemo(backend: _backend),
              OtpDemo(backend: _backend),
              BiometricDemo(backend: _backend),
              FaceDemo(backend: _backend),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.pin_outlined),
                selectedIcon: Icon(Icons.pin),
                label: 'MPIN',
              ),
              NavigationDestination(
                icon: Icon(Icons.sms_outlined),
                selectedIcon: Icon(Icons.sms),
                label: 'OTP',
              ),
              NavigationDestination(
                icon: Icon(Icons.fingerprint),
                label: 'Biometric',
              ),
              NavigationDestination(
                icon: Icon(Icons.face_outlined),
                selectedIcon: Icon(Icons.face),
                label: 'Face',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
