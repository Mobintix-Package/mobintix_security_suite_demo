# Mobintix Security Suite — Architecture & Code Review

> **Date:** 2026-04-06
> **Scope:** `mobintix_ui_kit` (v0.0.3) · `mobintix_security_suite` (v0.0.1) · `mobintix_security_suite_demo` (v1.0.0)
> **Flutter:** ≥3.41.0 · **Dart:** ≥3.11.0
> **Platforms:** Android, iOS, macOS, Web

---

## 1. Executive Summary

| Package | Grade | Summary |
|---------|-------|---------|
| **mobintix_ui_kit** | **Pass with Notes** | Solid token system (colors, spacing, radius, durations, sizing, shadows), 50+ widgets, responsive breakpoints, decent test coverage (~20 test files). Some JSON round-trip gaps and alpha versioning. Strongest piece of the three. |
| **mobintix_security_suite** | **Blocked** | Rigid `SecurityFlowHost` switch statement doesn't render its own enrollment/registration widgets. `SecurityFlowActions` is an untyped optional-callback bag. README documents a non-existent API. No accessibility, no responsiveness, negligible tests (2 files). |
| **mobintix_security_suite_demo** | **Pass with Notes** (after fixes) | Was a 719-line god widget with broken tests and stale README. **Now refactored** — orchestrator owns all state, screen is a thin shell, proper step progress bar, fintech-grade completion view, non-blocking startup. Remaining issues are in the SDK itself. |

**Overall verdict:** The UI Kit is production-ready with minor polish. The security suite SDK needs architectural rework before external consumption. The demo (post-fix) is now a proper reference app, but can only be as good as the SDK it wraps.

---

## 2. Checklist — Pass / Fail

### 2.1 mobintix_ui_kit

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Architecture & API surface | **PASS** | Pure composable widgets, named params with defaults, `ThemeExtension`-style tokens via `AppThemeScope` InheritedWidget. No singletons or globals. |
| 2 | Responsiveness | **PASS** | `Responsive` utility with xs/sm/md/lg/xl breakpoints, `ResponsiveBuilder`, `SafeContent` widget, `MediaQuery.textScalerOf` support, `shouldReduceMotion`. |
| 3 | Theming & Tokens | **PASS** | `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppDurations`, `AppSizing`, `AppShadows`. Light/dark factories. JSON serialisation. Material 3 compatible via `toThemeData()`. |
| 4 | Accessibility | **PASS** | `AppCard` has `semanticLabel` parameter, `Semantics` wrapper when provided. Minimum tap targets configurable via `AppSizing.minTapTarget` (defaults 48). |
| 5 | i18n / l10n | **MINOR** | No baked user-visible strings in the kit itself (it's a widget library). Labels are caller-provided. RTL not explicitly tested. |
| 6 | Performance | **PASS** | `const` constructors on config classes, `Equatable` for efficient rebuilds, `AnimatedContainer` with `shouldReduceMotion` checks. |
| 7 | Dependencies | **PASS** | Only `equatable` + `shimmer`. Both null-safe, MIT-licensed, stable. |
| 8 | Testing | **PASS*** | ~20 test files covering theme, responsive, buttons, inputs, cards, feedback, navigation, misc. No golden tests. Coverage target unknown. |
| 9 | Packaging | **MINOR** | `toJson()` on `AppTheme` omits `shadows` — round-trip loses shadow data. Version 0.0.3 signals pre-release. |

### 2.2 mobintix_security_suite

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Architecture & API surface | **FAIL** | `SecurityFlowHost` is a rigid switch — doesn't handle `BiometricEnrollmentView` or `FaceRegistrationView`. `SecurityFlowActions` is a flat bag of optional callbacks with no per-step type safety. |
| 2 | Responsiveness | **FAIL** | Zero usage of `LayoutBuilder`, `MediaQuery`, or UI Kit's `Responsive` utility in any SDK view widget. |
| 3 | Theming & Tokens | **PASS** | Reads from `mobintix_ui_kit` theme. `security_suite_theme.dart` exists for optional suite-specific extensions. |
| 4 | Accessibility | **FAIL** | No `Semantics` widgets in `MpinView`, `OtpView`, `BiometricView`, `FaceDetectionView`, `FaceRegistrationView`, `BiometricEnrollmentView`. No keyboard navigation, no focus management. |
| 5 | i18n / l10n | **FAIL** | Default English strings baked into view widgets. Overridable via config, but defaults are not externalised. |
| 6 | Performance | **PASS** | `const` config constructors, `Equatable` on all configs, `ValueKey` usage on views for efficient rebuilds. |
| 7 | Dependencies | **FAIL** | `path:` dependency on `mobintix_ui_kit` — not publishable to pub.dev. |
| 8 | Testing | **FAIL** | 2 test files (168 lines total). Only tests `SecurityFlowResponse` parsing and `SecurityFlowHost` for OTP + unknown step. No tests for MPIN, biometric, face detection, enrollment, or registration views. No golden tests. |
| 9 | Host Integration | **FAIL** | Consumer must manually implement enrollment/registration flows (~200+ lines) because `SecurityFlowHost` doesn't handle them. README documents callbacks that don't exist in the actual `SecurityFlowActions` class. |
| 10 | Error Handling | **FAIL** | No defensive checks for null/missing config, no graceful degradation. `ErrorState` widget exists but is only shown for missing `customStepBuilder`. |

### 2.3 mobintix_security_suite_demo (after refactor)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Architecture | **PASS** | `ChallengeOrchestrator` owns all state (session, enrollment, registration, detection). Screen is a thin UI shell that switches on `ChallengePhase`. |
| 2 | UI Quality | **PASS** | Step progress bar, proper completion view, error view with retry, tokenised spacing/radius/colors throughout. |
| 3 | State Management | **PASS** | `ChangeNotifier` with safe disposal (`_disposed` flag, `_delayOrCancel`). No stale closures — actions read current state at invocation time. |
| 4 | Non-blocking Startup | **PASS** | `seedIfEmpty()` fires with `unawaited()`. Catalog stream auto-updates. |
| 5 | Tests | **PASS*** | Compiles and tests `SecurityConfig` model. Needs integration tests. |
| 6 | README | **PASS** | Documents actual Firestore architecture, file structure, and current flow. |
| 7 | Credentials in Source | **FAIL** | `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist` still contain live Firebase keys. |

---

## 3. Issues & Recommendations

### BLOCKERS (SDK — must fix before any external release)

#### B1. `SecurityFlowHost` doesn't render enrollment/registration

**Severity:** Blocker
**File:** `mobintix_security_suite/lib/src/flow/security_flow_host.dart`
**Why it matters:** Consumers must re-implement 200+ lines of enrollment/registration logic that the SDK already exports as standalone widgets. This defeats the "drop-in flow" value proposition.

**Recommended fix — Option A (new step IDs):**

```dart
// security_flow_step_id.dart
enum SecurityFlowStepId {
  mpin,
  otp,
  biometric,
  biometricEnrollment,   // ← new
  faceDetection,
  faceRegistration,       // ← new
  deviceBinding,
  sessionWarning,
  done,
  unknown;
}
```

Then in `SecurityFlowHost.build()`:

```dart
case SecurityFlowStepId.biometricEnrollment:
  return BiometricEnrollmentView(
    config: flow.config as BiometricEnrollmentConfig,
    // ... wired from actions
  );
case SecurityFlowStepId.faceRegistration:
  return FaceRegistrationView(
    config: flow.config as FaceRegistrationConfig,
    // ... wired from actions
  );
```

**Recommended fix — Option B (enrollment as sub-state):**

Add `isEnrolled` / `isRegistered` flags to `BiometricConfig` / `FaceDetectionConfig`. When false, `SecurityFlowHost` renders enrollment/registration instead of verification.

---

#### B2. `SecurityFlowActions` is an untyped optional-callback bag

**Severity:** Blocker
**File:** `mobintix_security_suite/lib/src/flow/security_flow_actions.dart`
**Why it matters:** All 9 callbacks are optional. A consumer can pass `SecurityFlowActions()` and every button silently does nothing. No compile-time enforcement that required callbacks for a given step are provided.

**Recommended fix:**

```dart
sealed class SecurityFlowActions {
  const SecurityFlowActions();
}

class MpinFlowActions extends SecurityFlowActions {
  const MpinFlowActions({
    required this.onComplete,
    this.onForgotPin,
    this.onBiometric,
  });
  final Future<void> Function(String pin) onComplete;
  final Future<void> Function()? onForgotPin;
  final Future<void> Function()? onBiometric;
}

class OtpFlowActions extends SecurityFlowActions {
  const OtpFlowActions({
    required this.onComplete,
    this.onResend,
    this.onAlternate,
  });
  final Future<void> Function(String otp) onComplete;
  final Future<void> Function()? onResend;
  final Future<void> Function()? onAlternate;
}

// ... per step
```

Then `SecurityFlowHost` takes `SecurityFlowActions` and each branch casts to the expected type with a clear error if mismatched.

---

#### B3. README documents non-existent API

**Severity:** Blocker
**File:** `mobintix_security_suite/README.md`
**Why it matters:** Developers will copy-paste examples that don't compile.

**Evidence:** README shows `onDeviceBindingContinue`, `onSessionContinue`, `onDone`, `onBiometricFallback` — none exist in `SecurityFlowActions`.

**Fix:** Regenerate README from actual public API. Add a CI check that code samples compile.

---

#### B4. Path dependencies — unpublishable

**Severity:** Blocker
**Files:** `mobintix_security_suite/pubspec.yaml`, `mobintix_security_suite_demo/pubspec.yaml`

```yaml
# Current — only works on the author's machine
mobintix_ui_kit:
  path: ../mobintix_ui_kit
```

**Fix options:**
1. Publish to pub.dev (recommended for open source)
2. Use a private pub server (recommended for enterprise)
3. Use git dependency with tag/commit ref (minimum viable)

```yaml
# Option 3 — git ref
mobintix_ui_kit:
  git:
    url: https://github.com/Mobintix-Package/mobintix_ui_kit.git
    ref: v0.0.3
```

---

### MAJOR (SDK)

#### M1. No accessibility in SDK widgets

**Severity:** Major
**Files:** All view files in `mobintix_security_suite/lib/src/`
**Why it matters:** WCAG AA compliance is a regulatory requirement for fintech apps in most jurisdictions.

**Missing:**
- `Semantics` wrappers on PIN dots, keypad buttons, OTP fields
- `ExcludeSemantics` on decorative elements
- `FocusTraversalGroup` for logical tab order
- Keyboard input handling for keypad (physical keyboard users)
- `Semantics(label: 'PIN digit $i of $total')` on each pin dot

**Example fix for `MpinView`:**

```dart
Semantics(
  label: 'PIN entry. $filled of $total digits entered.',
  child: PinDots(
    length: config.mpinLength,
    filled: _pin.length,
    shape: config.pinDotShape,
  ),
),
```

---

#### M2. No responsive layouts in SDK widgets

**Severity:** Major
**Files:** All view files
**Why it matters:** The SDK depends on `mobintix_ui_kit` which has a full responsive system, but none of the security views use it. On tablets/web, PIN views will look stretched or tiny.

**Fix:** Wrap view bodies in `SafeContent` (from UI Kit) or use `Responsive.value()` for adaptive padding/sizing:

```dart
@override
Widget build(BuildContext context) {
  final maxWidth = Responsive.value<double>(
    context,
    xs: double.infinity,
    md: 420,
  );
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _buildContent(context),
    ),
  );
}
```

---

#### M3. `FaceDetectionView` in `SecurityFlowHost` missing params

**Severity:** Major
**File:** `mobintix_security_suite/lib/src/flow/security_flow_host.dart:65-73`
**Why it matters:** `FaceDetectionView` accepts `status` and `onRetry` parameters, but `SecurityFlowHost` doesn't pass them. The view always shows `FaceDetectionStatus.ready` and has no retry path.

**Fix:** Either add `status`/`onRetry` to the flow actions, or manage face detection state inside `SecurityFlowHost` as a StatefulWidget.

---

#### M4. Baked English strings with no externalization path

**Severity:** Major
**Files:** `mpin_view.dart`, `otp_view.dart`, `biometric_view.dart`, etc.
**Why it matters:** Fintech apps are multilingual. The SDK should expose all strings via config or provide a localisation delegate.

**Evidence (defaults in view widgets):**
- `"Enter your PIN"`, `"Verify"`, `"Resend OTP"`, `"Place your finger on the sensor"`
- Config can override *some* strings, but many are hard-coded in the widget build methods

**Fix:** Ensure EVERY user-visible string in SDK views is either:
1. Taken from the config object (already partially done), OR
2. Taken from a `SecuritySuiteLocalizations` delegate

---

### MAJOR (Demo)

#### M5. Firebase credentials committed to source

**Severity:** Major
**Files:** `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `macos/Runner/GoogleService-Info.plist`

**Why it matters:** API keys and project IDs are in plaintext in version control.

**Fix options:**
1. Use `--dart-define` to inject at build time
2. Use `firebase_app_check` for production
3. Add to `.gitignore` and document regeneration via `flutterfire configure`
4. At minimum, add a comment that these are demo-only keys

---

### MINOR

| # | Issue | File(s) | Fix |
|---|-------|---------|-----|
| m1 | `AppTheme.toJson()` omits `shadows` — round-trip lossy | `mobintix_ui_kit/.../app_theme.dart` | Add `'shadows': shadows.toJson()` to the map |
| m2 | SDK exports `painters.dart` — implementation detail leak | `mobintix_security_suite/lib/mobintix_security_suite.dart` | Remove from barrel; keep as `src/`-internal |
| m3 | `_GrainPainter` in demo repaints every frame with nested loops | `challenge_screen.dart` (old) | **Fixed** — removed in refactor |
| m4 | `SecurityStepConfig.fromJson` doesn't handle `BiometricEnrollmentConfig` or `FaceRegistrationConfig` | `security_step_config.dart` | Add cases for `biometricEnrollment` and `faceRegistration` step IDs |
| m5 | `ChallengeOrchestrator` — simulated delays are not configurable | Demo `challenge_orchestrator.dart` | Accept optional `Duration` parameters for testing/demo speed control |
| m6 | No `analysis_options.yaml` strict mode | Demo project | Enable `strict-casts`, `strict-raw-types`, `strict-inference` |

---

## 4. API & Tokenization Gaps

### Hard-coded values found (before demo refactor)

| Value | Location | Token to use |
|-------|----------|-------------|
| `EdgeInsets.symmetric(horizontal: 8, vertical: 3)` | `catalog_screen.dart` `_ChallengeBadge` | `spacing.xs` / `spacing.xxs` |
| `EdgeInsets.symmetric(horizontal: 10, vertical: 4)` | `challenge_screen.dart` step counter | `spacing.xs` / `spacing.xxs` |
| `BorderRadius.circular(12)` | Multiple places | `radius.md` |
| `size: 48` (icon) | Error/empty states | `sizing.iconLg` |
| `size: 44` (container) | Config card icon box | `sizing.avatarSm` |
| `Duration(seconds: 3)` | Face registration delay | `durations.slow` |
| `const SizedBox(width: 4)` | Badge internal spacing | `spacing.xxs` |

**Status:** All fixed in demo refactor. SDK widget internals should be audited separately.

### Missing tokens in UI Kit

| Token | Proposed name | Default | Purpose |
|-------|---------------|---------|---------|
| Border color | `AppColors.border` | `textSecondary.withOpacity(0.12)` | Consistent divider/border color without computing from textSecondary |
| Overlay dim | `AppColors.overlay` | `Colors.black54` | Modal/dialog backdrop |
| Focus ring | `AppColors.focusRing` | `primary.withOpacity(0.3)` | Accessibility focus indicator |

---

## 5. Test Plan Additions

### SDK — Missing test coverage

| Widget / Class | Test scenario | Priority |
|----------------|---------------|----------|
| `MpinView` | Renders title, accepts PIN digits, calls `onComplete` with full PIN, calls `onForgotPin` | High |
| `MpinView` | Create mode: shows confirm step, validates match | High |
| `OtpView` | Renders, accepts OTP, calls `onComplete`, resend cooldown timer works | High |
| `BiometricView` | Renders, calls `onPrimary`, calls `onAlternate` | Medium |
| `FaceDetectionView` | Renders with camera preview slot, calls `onCapture` | Medium |
| `BiometricEnrollmentView` | All status transitions render correctly (notEnrolled → awaitingScan → scanning → enrolling → enrolled) | Medium |
| `FaceRegistrationView` | All status transitions render correctly | Medium |
| `SecurityFlowHost` | Routes to correct view for EACH step type (not just OTP + unknown) | High |
| `SecurityStepConfig` | Round-trip `fromJson`/`toJson` for every config subclass | Medium |
| Golden: `MpinView` | Light + dark × xs + lg breakpoint | High |
| Golden: `OtpView` | Light + dark × xs + lg breakpoint | High |

**Estimated effort:** ~400 lines of test code, ~8 golden snapshots.

### Demo — Missing test coverage

| Test scenario | Priority |
|---------------|----------|
| `ChallengeOrchestrator` — start → completeChallenge → phase transitions | High |
| `ChallengeOrchestrator` — switchToAlternate changes currentChallenge | Medium |
| `ChallengeOrchestrator` — biometric enrollment state transitions | Medium |
| `CatalogScreen` — renders config cards from mocked stream | Medium |
| `ChallengeScreen` — completes MPIN challenge end-to-end | Low (integration) |

---

## 6. Integration Guide (for Host App)

### Minimum steps to consume `mobintix_security_suite`

```yaml
# pubspec.yaml
dependencies:
  mobintix_ui_kit: ^0.0.3
  mobintix_security_suite: ^0.0.1
```

#### Step 1 — Wrap app in `AppThemeScope`

```dart
runApp(
  AppThemeScope(
    theme: AppTheme.light(), // or AppTheme.dark() / AppTheme.fromJson(...)
    child: MaterialApp(
      theme: AppTheme.light().toThemeData(),
      home: const MyHomePage(),
    ),
  ),
);
```

#### Step 2 — Build a `SecurityFlowResponse` from your API

```dart
final apiResponse = await myApi.getNextChallenge(transactionId);
final flow = SecurityFlowResponse.fromJson(apiResponse);
```

#### Step 3 — Render with `SecurityFlowHost`

```dart
SecurityFlowHost(
  flow: flow,
  actions: SecurityFlowActions(
    onMpinComplete: (pin) async {
      await myApi.submitPin(transactionId, pin);
      _loadNextStep();
    },
    onOtpComplete: (otp) async {
      await myApi.submitOtp(transactionId, otp);
      _loadNextStep();
    },
    onBiometric: () async {
      final result = await localAuth.authenticate();
      if (result) {
        await myApi.submitBiometric(transactionId);
        _loadNextStep();
      }
    },
    onAlternate: () async => _showAlternatePicker(),
  ),
  cameraPreviewBuilder: (_) => const MyCameraWidget(),
  customStepBuilder: (flow) => MyCustomStep(flow: flow),
)
```

#### Step 4 — Handle enrollment/registration manually (current SDK limitation)

```dart
// Before showing biometric verification, check if enrolled
if (!userIsEnrolled) {
  // You must build BiometricEnrollmentView yourself
  return BiometricEnrollmentView(
    config: const BiometricEnrollmentConfig(),
    status: enrollmentStatus,
    scanProgress: scanProgress,
    totalScans: 3,
    onEnroll: () => startEnrollment(),
    // ...
  );
}
```

**This is the pain point that B1 addresses.** Once the SDK handles enrollment/registration internally, Step 4 goes away.

#### Step 5 — Customise theme tokens

```dart
final theme = AppTheme.light().copyWith(
  colors: AppColors.light().copyWith(
    primary: const Color(0xFF1E3A5F), // your brand color
  ),
  radius: AppRadius.defaults().copyWith(md: 16),
);
```

---

## 7. CI Recommendations

### Recommended pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'
          channel: stable
      - run: flutter pub get
        working-directory: mobintix_ui_kit
      - run: flutter pub get
        working-directory: mobintix_security_suite
      - run: flutter pub get
        working-directory: Demo/mobintix_security_suite_demo
      - run: flutter analyze --fatal-infos
        working-directory: mobintix_ui_kit
      - run: flutter analyze --fatal-infos
        working-directory: mobintix_security_suite
      - run: flutter analyze --fatal-infos
        working-directory: Demo/mobintix_security_suite_demo

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'
          channel: stable
      - run: flutter pub get && flutter test --coverage
        working-directory: mobintix_ui_kit
      - run: flutter pub get && flutter test --coverage
        working-directory: mobintix_security_suite
      - run: flutter pub get && flutter test
        working-directory: Demo/mobintix_security_suite_demo

  # goldens:
  #   runs-on: macos-latest   # golden pixel tests need consistent rendering
  #   steps:
  #     - uses: actions/checkout@v4
  #     - uses: subosito/flutter-action@v2
  #     - run: flutter pub get && flutter test --update-goldens
  #       working-directory: mobintix_ui_kit
```

### Local verification commands

```bash
# From repo root
cd mobintix_ui_kit && flutter analyze && flutter test --coverage && cd ..
cd mobintix_security_suite && flutter analyze && flutter test && cd ..
cd Demo/mobintix_security_suite_demo && flutter analyze && flutter test && cd ..
```

---

## 8. Fixes Applied in This Review

### Files modified in `mobintix_security_suite_demo`

| File | Change | Impact |
|------|--------|--------|
| `lib/services/challenge_orchestrator.dart` | Complete rewrite — owns all state (session, enrollment, registration, detection). Safe disposal with `_delayOrCancel`. `ChallengePhase` enum replaces scattered booleans. | Eliminates god-widget anti-pattern |
| `lib/screens/challenge_screen.dart` | Complete rewrite — thin UI shell. Added `_StepProgressBar`, `_CompletionView`, `_ErrorView`, `_CustomStepView`. Fixed stale closure bug in `_buildActions`. Professional snackbar messages. | Fintech-grade UX |
| `lib/screens/catalog_screen.dart` | Replaced developer-speak copy. Fixed hard-coded `EdgeInsets` → spacing tokens. Badges show human-readable labels. Consistent error/empty state design. | Professional polish |
| `lib/main.dart` | `seedIfEmpty()` → `unawaited()`. Non-blocking startup. | Instant app launch |
| `lib/utils/challenge_method.dart` | New shared file. Eliminates duplicated `_iconFor`/`_labelFor` in both screens. | DRY |
| `test/widget_test.dart` | Replaced broken test with compilable `SecurityConfig` model tests. | Tests actually run |
| `pubspec.yaml` | Fixed description. | Accurate metadata |
| `README.md` | Complete rewrite — documents actual Firestore architecture. | Accurate docs |

### Remaining items NOT fixed (require SDK changes)

| Item | Owner | Priority |
|------|-------|----------|
| B1 — `SecurityFlowHost` missing enrollment/registration | SDK | Blocker |
| B2 — `SecurityFlowActions` untyped callback bag | SDK | Blocker |
| B3 — SDK README documents non-existent API | SDK | Blocker |
| B4 — Path dependencies unpublishable | SDK + UI Kit | Blocker |
| M1 — No accessibility in SDK widgets | SDK | Major |
| M2 — No responsive layouts in SDK widgets | SDK | Major |
| M3 — `FaceDetectionView` missing params in host | SDK | Major |
| M4 — Baked English strings | SDK | Major |
| M5 — Firebase credentials in source | Demo | Major |
| m1 — `AppTheme.toJson()` shadow round-trip | UI Kit | Minor |
| m4 — `SecurityStepConfig.fromJson` missing enrollment/registration | SDK | Minor |

---

## 9. Architecture Diagram (Post-Refactor)

```
┌──────────────────────────────────────────────────────┐
│                    DemoApp (main.dart)                │
│  AppThemeScope → MaterialApp → CatalogScreen         │
└──────────────────────┬───────────────────────────────┘
                       │ Navigator.push
┌──────────────────────▼───────────────────────────────┐
│               ChallengeScreen (thin shell)           │
│  ┌─────────────────────────────────────────────────┐ │
│  │          ChallengeOrchestrator                   │ │
│  │  (ChangeNotifier — owns ALL state)              │ │
│  │                                                  │ │
│  │  ChallengePhase: initializing                   │ │
│  │               → biometricEnrollment             │ │
│  │               → faceRegistration                │ │
│  │               → activeChallenge                 │ │
│  │               → completed                       │ │
│  │               → error                           │ │
│  │                                                  │ │
│  │  Owns: session, config, enrollment status,      │ │
│  │        registration status, detection status    │ │
│  └─────────────────────┬───────────────────────────┘ │
│                        │ phase switch                 │
│  ┌─────────┬───────────┼────────────┬──────────────┐ │
│  │ Loading │ Enroll    │ SDK Views  │ Completion   │ │
│  │         │ Register  │ (FlowHost) │ View         │ │
│  └─────────┴───────────┴────────────┴──────────────┘ │
└──────────────────────────────────────────────────────┘
                       │
           ┌───────────▼───────────────┐
           │   mobintix_security_suite │
           │   SecurityFlowHost        │
           │   ├── MpinView            │
           │   ├── OtpView             │
           │   ├── BiometricView       │
           │   └── FaceDetectionView   │
           └───────────┬───────────────┘
                       │
           ┌───────────▼───────────────┐
           │     mobintix_ui_kit       │
           │  AppTheme · AppColors     │
           │  AppCard · NumericKeypad  │
           │  PinDots · PinInput       │
           │  Responsive · Spacing     │
           └───────────────────────────┘
```

---

*Review conducted on the full source of all three packages. All code examples reference actual file paths and line numbers in the repository.*
