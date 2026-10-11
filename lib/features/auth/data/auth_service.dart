import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  const AuthService({this.firebaseAuth, this.firestore});

  final FirebaseAuth? firebaseAuth;
  final FirebaseFirestore? firestore;

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
