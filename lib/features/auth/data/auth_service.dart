import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Returns an error message on failure, or null for a verified student.
  Future<String?> signInStudent(String email, String password) async {
    try {
      // Signs the student in with Firebase
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      var isStudent = false;
      try {
        final user = credential.user;
        if (user == null) {
          return 'Unable to sign in. Please try again.';
        }

        // Checks that the authenticated user has the student role
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));

        if (!profile.exists) {
          return 'Your user profile could not be found. Please contact support.';
        }
        if (profile.data()?['role'] != 'student') {
          return 'This account does not have student access.';
        }

        isStudent = true;
        return null;
      } finally {
        // Clears the session if the role check fails or cannot be completed.
        if (!isStudent) {
          await signOut();
        }
      }
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

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
