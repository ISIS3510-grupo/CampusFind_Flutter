import 'dart:async';

import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/auth/viewmodel/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  test('initial state is idle without a previous result or error', () {
    final model = AuthViewModel(
      authService: FakeAuthService(),
      biometricService: FakeBiometricService(),
    );
    addTearDown(model.dispose);
    expect(model.isBusy, isFalse);
    expect(model.isAuthenticated, isFalse);
    expect(model.needsPasswordSignIn, isFalse);
    expect(model.errorMessage, isNull);
  });

  test(
    'no saved session requests a password without using biometrics',
    () async {
      final biometrics = FakeBiometricService();
      final auth = FakeAuthService();
      final model = AuthViewModel(
        authService: auth,
        biometricService: biometrics,
      );
      addTearDown(model.dispose);
      await model.requestStudentAccess();
      expect(model.needsPasswordSignIn, isTrue);
      expect(model.isAuthenticated, isFalse);
      expect(model.isBusy, isFalse);
      expect(biometrics.availabilityChecks, 0);
      expect(auth.roleChecks, 0);
    },
  );

  test(
    'biometric success verifies the student role through AuthService',
    () async {
      final auth = FakeAuthService(savedSession: true);
      final biometrics = FakeBiometricService();
      final model = AuthViewModel(
        authService: auth,
        biometricService: biometrics,
      );
      addTearDown(model.dispose);
      await model.requestStudentAccess();
      expect(model.isAuthenticated, isTrue);
      expect(model.needsPasswordSignIn, isFalse);
      expect(model.errorMessage, isNull);
      expect(biometrics.authenticationCalls, 1);
      expect(auth.roleChecks, 1);
      expect(auth.passwordCalls, 0);
    },
  );

  for (final scenario in ['unavailable', 'cancelled', 'exception']) {
    test(
      '$scenario biometrics request a password and preserve the session',
      () async {
        final auth = FakeAuthService(savedSession: true);
        final biometrics = FakeBiometricService(
          available: scenario != 'unavailable',
          authenticated: scenario != 'cancelled',
          authenticationError: scenario == 'exception'
              ? StateError('Sensor failed')
              : null,
        );
        final model = AuthViewModel(
          authService: auth,
          biometricService: biometrics,
        );
        addTearDown(model.dispose);
        await model.requestStudentAccess();
        expect(model.needsPasswordSignIn, isTrue);
        expect(model.isAuthenticated, isFalse);
        expect(model.isBusy, isFalse);
        expect(auth.roleChecks, 0);
        expect(auth.signOutCalls, 0);
        expect(auth.savedSession, isTrue);
      },
    );
  }

  test('a rejected biometric role exposes the service error', () async {
    final auth = FakeAuthService(
      savedSession: true,
      roleError: 'Student access required.',
    );
    final model = AuthViewModel(
      authService: auth,
      biometricService: FakeBiometricService(),
    );
    addTearDown(model.dispose);
    await model.requestStudentAccess();
    expect(model.isAuthenticated, isFalse);
    expect(model.needsPasswordSignIn, isFalse);
    expect(model.errorMessage, 'Student access required.');
    expect(auth.savedSession, isTrue);
  });

  test(
    'password login delegates once and notifies busy and success states',
    () async {
      final auth = FakeAuthService();
      final model = AuthViewModel(authService: auth);
      addTearDown(model.dispose);
      final busyStates = <bool>[];
      model.addListener(() => busyStates.add(model.isBusy));
      expect(
        await model.signInStudent('student@uniandes.edu.co', 'password'),
        isTrue,
      );
      expect(auth.lastEmail, 'student@uniandes.edu.co');
      expect(auth.passwordCalls, 1);
      expect(auth.roleChecks, 1);
      expect(model.isAuthenticated, isTrue);
      expect(busyStates, [true, false]);
    },
  );

  test(
    'password or role rejection cannot authenticate a saved session',
    () async {
      for (final roleRejected in [false, true]) {
        final auth = FakeAuthService(
          savedSession: true,
          passwordError: roleRejected ? null : 'Wrong password.',
          roleError: roleRejected ? 'Wrong role.' : null,
        );
        final model = AuthViewModel(authService: auth);
        addTearDown(model.dispose);
        expect(
          await model.signInStudent('student@uniandes.edu.co', 'password'),
          isFalse,
        );
        expect(model.isAuthenticated, isFalse);
        expect(
          model.errorMessage,
          roleRejected ? 'Wrong role.' : 'Wrong password.',
        );
        expect(auth.signOutCalls, 0);
      }
    },
  );

  test('a successful retry clears a previous login error', () async {
    final auth = FakeAuthService(passwordError: 'Wrong password.');
    final model = AuthViewModel(authService: auth);
    addTearDown(model.dispose);
    await model.signInStudent('student@uniandes.edu.co', 'wrong');
    auth.passwordError = null;
    expect(
      await model.signInStudent('student@uniandes.edu.co', 'correct'),
      isTrue,
    );
    expect(model.errorMessage, isNull);
  });

  test(
    'unexpected password failure exposes an error and releases busy state',
    () async {
      final model = AuthViewModel(
        authService: FakeAuthService(passwordException: StateError('Failure')),
      );
      addTearDown(model.dispose);
      expect(
        await model.signInStudent('student@uniandes.edu.co', 'password'),
        isFalse,
      );
      expect(model.isBusy, isFalse);
      expect(model.errorMessage, 'Unable to sign in. Please try again.');
    },
  );

  test(
    'overlapping biometric and password actions do not start another request',
    () async {
      final pending = Completer<bool>();
      final auth = FakeAuthService(savedSession: true);
      final biometrics = FakeBiometricService(pendingResult: pending);
      final model = AuthViewModel(
        authService: auth,
        biometricService: biometrics,
      );
      addTearDown(model.dispose);
      final access = model.requestStudentAccess();
      await Future<void>.delayed(Duration.zero);
      expect(model.isBusy, isTrue);
      await model.requestStudentAccess();
      expect(
        await model.signInStudent('student@uniandes.edu.co', 'password'),
        isFalse,
      );
      expect(biometrics.authenticationCalls, 1);
      expect(auth.passwordCalls, 0);
      pending.complete(true);
      await access;
      expect(model.isAuthenticated, isTrue);
    },
  );

  test(
    'a session lost during biometric unlock falls back to password',
    () async {
      final pending = Completer<bool>();
      final auth = FakeAuthService(savedSession: true);
      final model = AuthViewModel(
        authService: auth,
        biometricService: FakeBiometricService(pendingResult: pending),
      );
      addTearDown(model.dispose);
      final access = model.requestStudentAccess();
      await Future<void>.delayed(Duration.zero);
      auth.savedSession = false;
      pending.complete(true);
      await access;
      expect(model.needsPasswordSignIn, isTrue);
      expect(auth.roleChecks, 0);
    },
  );

  test(
    'disposal during biometrics stops follow-up work and notifications',
    () async {
      final pending = Completer<bool>();
      final auth = FakeAuthService(savedSession: true);
      final model = AuthViewModel(
        authService: auth,
        biometricService: FakeBiometricService(pendingResult: pending),
      );
      var notifications = 0;
      model.addListener(() => notifications++);
      final access = model.requestStudentAccess();
      await Future<void>.delayed(Duration.zero);
      model.dispose();
      pending.complete(true);
      await access;
      await model.requestStudentAccess();
      expect(notifications, 1);
      expect(auth.roleChecks, 0);
    },
  );

  test(
    'disposal during password login does not notify or navigate on completion',
    () async {
      final pending = Completer<String?>();
      final model = AuthViewModel(
        authService: FakeAuthService(pendingPassword: pending),
      );
      var notifications = 0;
      model.addListener(() => notifications++);
      final signingIn = model.signInStudent(
        'student@uniandes.edu.co',
        'password',
      );
      model.dispose();
      pending.complete(null);
      expect(await signingIn, isFalse);
      expect(notifications, 1);
      expect(model.isAuthenticated, isFalse);
    },
  );

  group('Login ViewModel ownership', () {
    setUpAll(loadTestFonts);
    testWidgets('Login leaves an injected ViewModel owned by its caller', (
      tester,
    ) async {
      final model = AuthViewModel(authService: FakeAuthService());
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(home: LoginScreen(viewModel: model)));
      await tester.pumpWidget(const SizedBox());
      expect(
        await model.signInStudent('student@uniandes.edu.co', 'password'),
        isTrue,
      );
      expect(model.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Login disposes its internal ViewModel while work is pending', (
      tester,
    ) async {
      final pending = Completer<bool>();
      final auth = FakeAuthService(savedSession: true);
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: auth,
            biometricService: FakeBiometricService(pendingResult: pending),
          ),
        ),
      );
      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(auth.roleChecks, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
