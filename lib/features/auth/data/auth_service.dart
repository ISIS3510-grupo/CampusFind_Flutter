import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'microsoft_sign_in.dart';

class AuthService {
  const AuthService({
    this.firebaseAuth,
    this.firestore,
    this.microsoftSignIn = const MsalMicrosoftSignIn(),
  });

  final FirebaseAuth? firebaseAuth;
  final FirebaseFirestore? firestore;
  final MicrosoftSignIn microsoftSignIn;

  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => firestore ?? FirebaseFirestore.instance;

  bool get hasCurrentUser => _auth.currentUser != null;

  String? get currentUserId => _auth.currentUser?.uid;

  // Returns an error message on failure, or null for a verified student.
  Future<String?> signInStudent(String email, String password) async {
    try {
      // Signs the student in with Firebase
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return await verifyStudentRole();
    } on FirebaseAuthException catch (error) {
      return _signInError(error);
    } on FirebaseException {
      return 'Unable to verify your student account. Please try again.';
    } catch (_) {
      return 'Unable to sign in. Please try again.';
    }
  }

  // Both password login and biometric unlock use this student role check.
  Future<String?> verifyStudentRole() async {
    String? error;
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Please sign in again.';

      final profile = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));

      if (!profile.exists) {
        error = 'Your user profile could not be found. Please contact support.';
      } else if (profile.data()?['role'] != 'student') {
        error = 'This account does not have student access.';
      }
    } catch (_) {
      error = 'Unable to verify your student account. Please try again.';
    }

    // Failed verification denies access without signing out the saved session.
    return error;
  }

  // Single sign-on with the student's Uniandes Microsoft account (MSAL). The
  // first time a student enters this way, their student profile is created.
  Future<String?> signInStudentWithMicrosoft() async {
    var authenticated = false;
    String? error;
    try {
      final customToken = await microsoftSignIn.firebaseCustomToken();
      if (customToken == null) return 'Microsoft sign in was cancelled.';

      final credential = await _auth.signInWithCustomToken(customToken);
      final user = credential.user;
      if (user == null) return 'Unable to sign in with Microsoft.';
      authenticated = true;

      if (!_isUniandesEmail(user.email)) {
        error = 'Use your @uniandes.edu.co Microsoft account.';
      } else {
        await _ensureStudentProfile(user);
        error = await verifyStudentRole();
      }
    } on MicrosoftSignInException catch (exception) {
      error = exception.message;
    } on FirebaseAuthException catch (exception) {
      debugPrint('Microsoft sign in, Firebase Auth failed: ${exception.code}');
      error = _signInError(exception);
    } on FirebaseException catch (exception) {
      debugPrint(
        'Microsoft sign in, student profile failed: '
        '${exception.plugin}/${exception.code}',
      );
      error = 'Unable to verify your student account. Please try again.';
    } catch (exception) {
      debugPrint('Microsoft sign in failed: $exception');
      error = 'Unable to sign in with Microsoft. Please try again.';
    }

    if (authenticated && error != null) {
      try {
        await signOut();
      } catch (_) {}
    }
    return error;
  }

  Future<void> _ensureStudentProfile(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final profile = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (profile.exists) return;
    final email = user.email!;
    await reference.set({
      'email': email,
      'displayName': user.displayName ?? email.split('@').first,
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  bool _isUniandesEmail(String? email) {
    final parts = (email ?? '').toLowerCase().split('@');
    return parts.length == 2 &&
        parts.first.isNotEmpty &&
        parts.last == 'uniandes.edu.co';
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> signInAdmin(String email, String password) async {
    var authenticated = false;
    String? error;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      authenticated = true;
      error = await verifyAdminRole();
    } on FirebaseAuthException catch (exception) {
      error = _signInError(exception);
    } on FirebaseException {
      error = 'Unable to verify your staff account. Please try again.';
    } catch (_) {
      error = 'Unable to sign in. Please try again.';
    }

    if (authenticated && error != null) {
      try {
        await signOut();
      } catch (_) {
        return 'Staff access denied. Unable to clear the session. Please try again.';
      }
    }
    return error;
  }

  Future<String?> verifyAdminRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Please sign in again.';
      final emailParts = (user.email ?? '').toLowerCase().split('@');
      if (emailParts.length != 2 ||
          emailParts.first.isEmpty ||
          emailParts.last != 'uniandes.edu.co') {
        return 'Staff access requires a Uniandes email address.';
      }
      if (!user.emailVerified) {
        return 'Please verify your Uniandes email before accessing staff tools.';
      }

      final profile = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (_auth.currentUser?.uid != user.uid) return 'Please sign in again.';
      if (!profile.exists) return 'Your staff profile could not be found.';
      if (profile.data()?['role'] != 'admin') {
        return 'This account does not have staff access.';
      }
      return null;
    } catch (_) {
      return 'Unable to verify your staff account. Please try again.';
    }
  }

  String _signInError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password. Please try again.';
      case 'user-disabled':
        return 'This account is disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Unable to connect. Please try again.';
      default:
        return 'Unable to sign in. Please try again.';
    }
  }
}
