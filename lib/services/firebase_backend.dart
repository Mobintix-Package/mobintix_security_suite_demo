import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

const _faceMatchThreshold = 0.12;

/// Simulates a backend using Firestore.
///
/// Each security feature gets its own document under:
///   users/{userId}/security/{mpin|otp|biometric|face}
///
/// In production, these operations would live on a server.
/// Here we put them in the client to demonstrate the data flow
/// without requiring a separate backend deployment.
class FirebaseBackend {
  FirebaseBackend({String userId = 'demo_user'})
      : _security = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('security');

  final CollectionReference<Map<String, dynamic>> _security;
  final _rand = Random.secure();

  DocumentReference<Map<String, dynamic>> get _mpinDoc => _security.doc('mpin');
  DocumentReference<Map<String, dynamic>> get _otpDoc => _security.doc('otp');
  DocumentReference<Map<String, dynamic>> get _bioDoc =>
      _security.doc('biometric');
  DocumentReference<Map<String, dynamic>> get _faceDoc =>
      _security.doc('face');

  // ---------------------------------------------------------------------------
  // MPIN  →  users/demo_user/security/mpin
  // ---------------------------------------------------------------------------

  String _hashPin(String pin) =>
      sha256.convert(utf8.encode('mpin_salt_$pin')).toString();

  Future<bool> isMpinCreated() async {
    final snap = await _mpinDoc.get();
    return snap.exists && snap.data()?['hash'] != null;
  }

  Future<void> createMpin(String pin) async {
    await _mpinDoc.set({
      'hash': _hashPin(pin),
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> verifyMpin(String pin) async {
    final snap = await _mpinDoc.get();
    final stored = snap.data()?['hash'] as String?;
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  // ---------------------------------------------------------------------------
  // OTP  →  users/demo_user/security/otp
  // ---------------------------------------------------------------------------

  Future<String> generateOtp() async {
    final code = List.generate(6, (_) => _rand.nextInt(10)).join();
    await _otpDoc.set({
      'code': code,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 120)),
      ),
    });
    return code;
  }

  Future<bool> verifyOtp(String code) async {
    final snap = await _otpDoc.get();
    final data = snap.data();
    if (data == null) return false;

    final stored = data['code'] as String?;
    final expires = data['expires_at'] as Timestamp?;

    if (stored == null || stored != code) return false;
    if (expires != null && expires.toDate().isBefore(DateTime.now())) {
      return false;
    }

    await _otpDoc.update({'code': FieldValue.delete(), 'verified': true});
    return true;
  }

  // ---------------------------------------------------------------------------
  // Biometric  →  users/demo_user/security/biometric
  // ---------------------------------------------------------------------------

  Future<bool> isBiometricEnrolled() async {
    final snap = await _bioDoc.get();
    return snap.data()?['enrolled'] == true;
  }

  Future<void> enrollBiometric() async {
    await _bioDoc.set({
      'enrolled': true,
      'enrolled_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordBiometricAuth() async {
    await _bioDoc.update({
      'last_auth': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Face  →  users/demo_user/security/face
  // ---------------------------------------------------------------------------

  Future<bool> isFaceRegistered() async {
    final snap = await _faceDoc.get();
    return snap.data()?['registered'] == true;
  }

  /// Stores normalized face landmark ratios as the registered face signature.
  Future<void> registerFace(Map<String, double> signature) async {
    await _faceDoc.set({
      'registered': true,
      'signature': signature,
      'registered_at': FieldValue.serverTimestamp(),
    });
  }

  /// Compares [signature] against the stored registration.
  /// Returns a [FaceMatchResult] with the Euclidean distance and pass/fail.
  Future<FaceMatchResult> verifyFace(Map<String, double> signature) async {
    final snap = await _faceDoc.get();
    final data = snap.data();
    if (data == null || data['registered'] != true) {
      return const FaceMatchResult(distance: double.infinity, matched: false);
    }

    final stored = (data['signature'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, (v as num).toDouble()));
    if (stored == null || stored.isEmpty) {
      return const FaceMatchResult(distance: double.infinity, matched: false);
    }

    double sumSq = 0;
    int count = 0;
    for (final key in stored.keys) {
      if (signature.containsKey(key)) {
        final diff = stored[key]! - signature[key]!;
        sumSq += diff * diff;
        count++;
      }
    }
    if (count == 0) {
      return const FaceMatchResult(distance: double.infinity, matched: false);
    }

    final distance = sqrt(sumSq / count);
    final matched = distance <= _faceMatchThreshold;

    if (matched) {
      await _faceDoc.update({'last_auth': FieldValue.serverTimestamp()});
    }

    return FaceMatchResult(distance: distance, matched: matched);
  }

  // ---------------------------------------------------------------------------
  // Reset — deletes all four documents
  // ---------------------------------------------------------------------------

  Future<void> resetAll() async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_mpinDoc);
    batch.delete(_otpDoc);
    batch.delete(_bioDoc);
    batch.delete(_faceDoc);
    await batch.commit();
  }
}

/// Result of a face verification attempt.
class FaceMatchResult {
  const FaceMatchResult({required this.distance, required this.matched});

  /// Root-mean-square distance between stored and live face signatures.
  /// Lower is more similar. A value ≤ [_faceMatchThreshold] is a match.
  final double distance;

  final bool matched;
}
