import 'dart:async';

import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/auth/data/biometric_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({
    this.savedSession = false,
    this.roleError,
    this.passwordError,
    this.failSignOut = false,
    this.pendingPassword,
    this.pendingRole,
    this.pendingSignOut,
    this.passwordException,
  });

  bool savedSession;
  String? roleError;
  String? passwordError;
  bool failSignOut;
  final Completer<String?>? pendingPassword;
  final Completer<String?>? pendingRole;
  final Completer<void>? pendingSignOut;
  final Object? passwordException;
  int roleChecks = 0;
  int passwordCalls = 0;
  int signOutCalls = 0;
  String? lastEmail;

  @override
  bool get hasCurrentUser => savedSession;

  @override
  String? get currentUserId => savedSession ? 'student-1' : null;

  @override
  Future<String?> verifyStudentRole() async {
    roleChecks++;
    return pendingRole == null ? roleError : await pendingRole!.future;
  }

  @override
  Future<String?> signInStudent(String email, String password) async {
    passwordCalls++;
    lastEmail = email;
    if (passwordException != null) throw passwordException!;
    final error = pendingPassword == null
        ? passwordError
        : await pendingPassword!.future;
    if (error != null) return error;
    savedSession = true;
    return verifyStudentRole();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (pendingSignOut != null) await pendingSignOut!.future;
    if (failSignOut) throw StateError('Sign-out failed');
    savedSession = false;
  }
}

class FakeBiometricService extends BiometricService {
  FakeBiometricService({
    this.available = true,
    this.authenticated = true,
    this.pendingResult,
    this.authenticationError,
  });

  final bool available;
  final bool authenticated;
  final Completer<bool>? pendingResult;
  final Object? authenticationError;
  int availabilityChecks = 0;
  int authenticationCalls = 0;

  @override
  Future<bool> canAuthenticate() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<bool> authenticate() async {
    authenticationCalls++;
    if (authenticationError != null) throw authenticationError!;
    return pendingResult?.future ?? Future.value(authenticated);
  }
}
