import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  const AuthService();

  bool get hasCurrentUser => FirebaseAuth.instance.currentUser != null;

  // Returns an error message on failure, or null for a verified student.
  Future<String?> signInStudent(String email, String password) async {
    try {
      // Signs the student in with Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return await verifyStudentRole();
    } on FirebaseAuthException catch (error) {
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Please sign in again.';

      final profile = await FirebaseFirestore.instance
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

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
