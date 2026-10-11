import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/firestore_fakes.dart';

void main() {
  late FakeFirebaseAuthClient auth;
  late FakeFirestore database;
  late AuthService service;

  setUp(() {
    auth = FakeFirebaseAuthClient(signInUser: FakeFirebaseUser());
    database = FakeFirestore(
      documents: {
        'users/staff-test': {'role': 'admin'},
      },
    );
    service = AuthService(firebaseAuth: auth, firestore: database);
  });

  test(
    'admin login authenticates supplied credentials and checks server profile',
    () async {
      expect(
        await service.signInAdmin(
          ' staff@uniandes.edu.co ',
          'entered-password',
        ),
        isNull,
      );
      expect(auth.lastEmail, 'staff@uniandes.edu.co');
      expect(auth.lastPassword, 'entered-password');
      expect(auth.signInCalls, 1);
      expect(auth.signOutCalls, 0);
      expect(database.documentReads, ['users/staff-test']);
      expect(database.documentReadOptions.single?.source, Source.server);
      expect(database.queries, isEmpty);
      expect(database.documentWrites, isEmpty);
      expect(service.hasCurrentUser, isTrue);
    },
  );

  for (final role in <Object?>['student', 'staff', 'Admin', null, 1]) {
    test(
      'role $role is denied and its authenticated session is cleared',
      () async {
        database.documents['users/staff-test'] = {'role': role};
        expect(
          await service.signInAdmin('staff@uniandes.edu.co', 'password'),
          'This account does not have staff access.',
        );
        expect(auth.signOutCalls, 1);
        expect(auth.currentUser, isNull);
      },
    );
  }

  test(
    'missing staff profile returns readable error and clears session',
    () async {
      database.documents.clear();
      expect(
        await service.signInAdmin('staff@uniandes.edu.co', 'password'),
        'Your staff profile could not be found.',
      );
      expect(auth.currentUser, isNull);
    },
  );

  test('profile read failure denies access and clears session', () async {
    service = AuthService(
      firebaseAuth: auth,
      firestore: FakeFirestore(
        errors: {
          'users/staff-test': FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        },
      ),
    );
    expect(
      await service.signInAdmin('staff@uniandes.edu.co', 'password'),
      'Unable to verify your staff account. Please try again.',
    );
    expect(auth.currentUser, isNull);
  });

  test('unverified institutional account cannot enter staff tools', () async {
    auth = FakeFirebaseAuthClient(
      signInUser: FakeFirebaseUser(emailVerified: false),
    );
    service = AuthService(firebaseAuth: auth, firestore: database);
    expect(
      await service.signInAdmin('staff@uniandes.edu.co', 'password'),
      'Please verify your Uniandes email before accessing staff tools.',
    );
    expect(auth.currentUser, isNull);
    expect(database.documentReads, isEmpty);
  });

  for (final email in <String?>[
    'staff@example.com',
    'staff@uniandes.edu.co.evil.com',
    'staff@sub.uniandes.edu.co',
    null,
  ]) {
    test(
      'authenticated email $email is rejected regardless of entered email',
      () async {
        auth = FakeFirebaseAuthClient(
          signInUser: FakeFirebaseUser(email: email),
        );
        service = AuthService(firebaseAuth: auth, firestore: database);
        expect(
          await service.signInAdmin('staff@uniandes.edu.co', 'password'),
          'Staff access requires a Uniandes email address.',
        );
        expect(auth.currentUser, isNull);
        expect(database.documentReads, isEmpty);
      },
    );
  }

  test('institutional email domain comparison is case insensitive', () async {
    auth = FakeFirebaseAuthClient(
      signInUser: FakeFirebaseUser(email: 'Staff@Uniandes.edu.co'),
    );
    service = AuthService(firebaseAuth: auth, firestore: database);
    expect(
      await service.signInAdmin('Staff@Uniandes.edu.co', 'password'),
      isNull,
    );
  });

  test('role verification without a current user rejects access', () async {
    expect(await service.verifyAdminRole(), 'Please sign in again.');
    expect(database.documentReads, isEmpty);
  });

  test(
    'invalid credentials return an error without checking a profile',
    () async {
      auth.signInError = FirebaseAuthException(code: 'invalid-credential');
      expect(
        await service.signInAdmin('staff@uniandes.edu.co', 'wrong'),
        'Incorrect email or password. Please try again.',
      );
      expect(database.documentReads, isEmpty);
      expect(auth.currentUser, isNull);
    },
  );

  test('unexpected authentication failure does not report success', () async {
    auth.signInError = StateError('Unexpected');
    expect(
      await service.signInAdmin('staff@uniandes.edu.co', 'password'),
      'Unable to sign in. Please try again.',
    );
    expect(database.documentReads, isEmpty);
  });

  test(
    'cleanup failure still returns an error rather than granting access',
    () async {
      database.documents['users/staff-test'] = {'role': 'student'};
      auth.failSignOut = true;
      expect(
        await service.signInAdmin('staff@uniandes.edu.co', 'password'),
        'Staff access denied. Unable to clear the session. Please try again.',
      );
      expect(auth.signOutCalls, 1);
    },
  );

  test(
    'student role denial still preserves its existing Firebase session',
    () async {
      expect(
        await service.signInStudent('staff@uniandes.edu.co', 'password'),
        'This account does not have student access.',
      );
      expect(auth.currentUser, isNotNull);
      expect(auth.signOutCalls, 0);
    },
  );

  test(
    'student login keeps its existing domain and verification behavior',
    () async {
      auth = FakeFirebaseAuthClient(
        signInUser: FakeFirebaseUser(
          email: 'student@example.com',
          emailVerified: false,
        ),
      );
      database.documents['users/staff-test'] = {'role': 'student'};
      service = AuthService(firebaseAuth: auth, firestore: database);
      expect(
        await service.signInStudent('student@example.com', 'password'),
        isNull,
      );
      expect(auth.signOutCalls, 0);
    },
  );
}
