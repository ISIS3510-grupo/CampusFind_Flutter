import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final _localAuth = LocalAuthentication();

  // Checks for biometric hardware and at least one enrolled biometric.
  Future<bool> canAuthenticate() async {
    try {
      if (!await _localAuth.canCheckBiometrics) return false;
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  // Uses the device biometric sensor to unlock the current session.
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason:
            'Use your biometric authentication to access CampusFind',
        biometricOnly: true,
      );
    } on LocalAuthException {
      // Cancellation, lockout, and unavailable biometrics leave S01 open.
      return false;
    } on PlatformException {
      return false;
    }
  }
}
