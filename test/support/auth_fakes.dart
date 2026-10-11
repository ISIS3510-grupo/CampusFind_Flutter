import 'dart:async';

import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/auth/data/biometric_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

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
    this.adminPasswordError,
    this.adminRoleError,
    this.pendingAdmin,
    this.adminException,
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
  String? adminPasswordError;
  String? adminRoleError;
  Completer<String?>? pendingAdmin;
  Object? adminException;
  int adminCalls = 0;
  int adminRoleChecks = 0;
  String? lastAdminEmail;
  String? lastAdminPassword;

  @override
  Future<String?> verifyAdminRole() async {
    adminRoleChecks++;
    return adminRoleError;
  }

  @override
  Future<String?> signInAdmin(String email, String password) async {
    adminCalls++;
    lastAdminEmail = email;
    lastAdminPassword = password;
    if (adminException != null) throw adminException!;
    final error = pendingAdmin == null
        ? adminPasswordError
        : await pendingAdmin!.future;
    if (error != null) return error;
    savedSession = true;
    final roleError = await verifyAdminRole();
    if (roleError != null) await signOut();
    return roleError;
  }

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

// SDK doubles exercise AuthService itself without contacting Firebase.
class FakeFirebaseAuthClient extends Fake implements FirebaseAuth {
  FakeFirebaseAuthClient({required this.signInUser});

  final User signInUser;
  @override
  User? currentUser;
  Object? signInError;
  bool failSignOut = false;
  int signInCalls = 0;
  int signOutCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    if (signInError != null) throw signInError!;
    currentUser = signInUser;
    return _FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw StateError('Sign-out failed');
    currentUser = null;
  }
}

class FakeFirebaseUser extends Fake implements User {
  FakeFirebaseUser({
    this.uid = 'staff-test',
    this.email = 'staff@uniandes.edu.co',
    this.emailVerified = true,
  });

  @override
  final String uid;
  @override
  final String? email;
  @override
  final bool emailVerified;
}

class _FakeUserCredential extends Fake implements UserCredential {}
