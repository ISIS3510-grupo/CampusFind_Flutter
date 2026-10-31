import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/auth/data/microsoft_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/firestore_fakes.dart';

void main() {
  const student = 'ms-student';

  ({AuthService service, FakeFirebaseAuthClient auth, FakeFirestore db})
  setUpService({
    FakeMicrosoftSignIn? microsoft,
    String email = 'ana@uniandes.edu.co',
    Map<String, Map<String, dynamic>> documents = const {},
  }) {
    final auth = FakeFirebaseAuthClient(
      signInUser: FakeFirebaseUser(
        uid: student,
        email: email,
        displayName: 'Ana Pérez',
      ),
    );
    final db = FakeFirestore(documents: documents);
    return (
      service: AuthService(
        firebaseAuth: auth,
        firestore: db,
        microsoftSignIn: microsoft ?? FakeMicrosoftSignIn(),
      ),
      auth: auth,
      db: db,
    );
  }

  test('first Microsoft sign in creates the student profile', () async {
    final (:service, :auth, :db) = setUpService();

    expect(await service.signInStudentWithMicrosoft(), isNull);

    expect(auth.lastCustomToken, 'custom-token');
    final profile = db.documents['users/$student']!;
    expect(profile['email'], 'ana@uniandes.edu.co');
    expect(profile['displayName'], 'Ana Pérez');
    expect(profile['role'], 'student');
    expect(auth.signOutCalls, 0);
  });

  test('a returning student keeps the existing profile', () async {
    final existing = {
      'email': 'ana@uniandes.edu.co',
      'displayName': 'Ana',
      'role': 'student',
    };
    final (:service, :auth, :db) = setUpService(
      documents: {'users/$student': existing},
    );

    expect(await service.signInStudentWithMicrosoft(), isNull);

    expect(db.documentWrites, isEmpty);
    expect(db.documents['users/$student'], existing);
  });

  test('closing the Microsoft sign in does not touch Firebase', () async {
    final (:service, :auth, :db) = setUpService(
      microsoft: FakeMicrosoftSignIn(customToken: null),
    );

    expect(
      await service.signInStudentWithMicrosoft(),
      'Microsoft sign in was cancelled.',
    );
    expect(auth.signInCalls, 0);
  });

  test('a rejected Microsoft account shows its message', () async {
    final (:service, :auth, :db) = setUpService(
      microsoft: FakeMicrosoftSignIn(
        error: const MicrosoftSignInException(
          'Use your @uniandes.edu.co Microsoft account.',
        ),
      ),
    );

    expect(
      await service.signInStudentWithMicrosoft(),
      'Use your @uniandes.edu.co Microsoft account.',
    );
    expect(auth.signInCalls, 0);
  });

  test('a non Uniandes email is signed out again', () async {
    final (:service, :auth, :db) = setUpService(email: 'ana@gmail.com');

    expect(
      await service.signInStudentWithMicrosoft(),
      'Use your @uniandes.edu.co Microsoft account.',
    );
    expect(auth.signOutCalls, 1);
    expect(db.documentWrites, isEmpty);
  });

  test('a staff profile cannot enter as a student', () async {
    final (:service, :auth, :db) = setUpService(
      documents: {
        'users/$student': {
          'email': 'ana@uniandes.edu.co',
          'displayName': 'Ana',
          'role': 'admin',
        },
      },
    );

    expect(
      await service.signInStudentWithMicrosoft(),
      'This account does not have student access.',
    );
    expect(auth.signOutCalls, 1);
  });

  test('signing out also forgets the Microsoft account', () async {
    final microsoft = FakeMicrosoftSignIn();
    final (:service, :auth, db: _) = setUpService(microsoft: microsoft);

    expect(await service.signInStudentWithMicrosoft(), isNull);
    await service.signOut();

    expect(auth.signOutCalls, 1);
    expect(microsoft.signOuts, 1);
  });
}
