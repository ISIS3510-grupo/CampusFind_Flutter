import 'dart:async';

import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:campusfind_flutter/core/data/lost_report_repository.dart';
import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/auth/viewmodel/auth_view_model.dart';

import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:campusfind_flutter/viewmodels/item_viewmodel.dart';
import 'package:campusfind_flutter/views/report_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';
import 'support/firestore_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Login screen displays the access options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CampusFindApp());

    expect(find.text('Lost & Found'), findsOneWidget);
    expect(find.text('Enter with Uniandes'), findsOneWidget);
    expect(find.text('Staff access'), findsOneWidget);

    final auth = FakeAuthService();
    final biometrics = FakeBiometricService();
    await _pumpLogin(tester, auth, biometrics);
    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();
    expect(biometrics.availabilityChecks, 0);
    expect(biometrics.authenticationCalls, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );

    // Empty input is checked locally, without calling Firebase.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email and password.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Staff access'));
    await tester.pumpAndSettle();
    expect(find.text('Staff sign in'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Lost & Found'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Staff access'));
    await tester.pumpAndSettle();
    expect(find.text('Lost & Found'), findsOneWidget);
    expect(find.text('Enter with Uniandes'), findsOneWidget);
    expect(find.text('Staff access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home opens found reporting and preserves the other inactive actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 42);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ItemViewModel(),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeScreen(
              authService: FakeAuthService(savedSession: true),
              lostReportRepository: LostReportRepository(
                firestore: FakeFirestore(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in [
        'Lost & Found',
        'What do you need?',
        'Search found items',
        'I found an item',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('My active report'), findsNothing);
      expect(find.text('Scientific calculator'), findsNothing);
      expect(find.text('Possible match'), findsNothing);

      await tester.tap(find.text('I found an item'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReportItemScreen>(find.byType(ReportItemScreen))
            .reportType,
        'found',
      );
      expect(find.text('Report Found Item'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Correo Uniandes'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      for (final text in ['Search found items', 'Home', 'Search', 'Profile']) {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          0,
        );
      }
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      expect(find.text('My active report'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Saved student session opens Home after biometric success', (
    tester,
  ) async {
    final auth = FakeAuthService(savedSession: true);
    final biometrics = FakeBiometricService();
    await _pumpLogin(tester, auth, biometrics);

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();

    expect(biometrics.authenticationCalls, 1);
    expect(auth.roleChecks, 1);
    expect(auth.passwordCalls, 0);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'Biometric false opens password login without role checks or navigation',
    (tester) async {
      final auth = FakeAuthService(savedSession: true);
      final biometrics = FakeBiometricService(authenticated: false);
      await _pumpLogin(tester, auth, biometrics);

      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pumpAndSettle();

      expect(auth.roleChecks, 0);
      expect(auth.signOutCalls, 0);
      expect(auth.hasCurrentUser, isTrue);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(biometrics.authenticationCalls, 1);

      await tester.enterText(
        find.byType(TextField).first,
        'student@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'test-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(auth.passwordCalls, 1);
      expect(auth.roleChecks, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('Unavailable biometrics fall back to the password dialog', (
    tester,
  ) async {
    final auth = FakeAuthService(savedSession: true);
    final biometrics = FakeBiometricService(available: false);
    await _pumpLogin(tester, auth, biometrics);

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();

    expect(biometrics.availabilityChecks, 1);
    expect(biometrics.authenticationCalls, 0);
    expect(auth.roleChecks, 0);
    expect(auth.signOutCalls, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Biometric success cannot bypass a rejected student role', (
    tester,
  ) async {
    final auth = FakeAuthService(
      savedSession: true,
      roleError: 'This account does not have student access.',
    );
    await _pumpLogin(tester, auth, FakeBiometricService());

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();

    expect(auth.roleChecks, 1);
    expect(auth.signOutCalls, 0);
    expect(auth.hasCurrentUser, isTrue);
    expect(
      find.text('This account does not have student access.'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Repeated taps do not start another biometric prompt', (
    tester,
  ) async {
    final result = Completer<bool>();
    final auth = FakeAuthService(savedSession: true);
    final biometrics = FakeBiometricService(pendingResult: result);
    await _pumpLogin(tester, auth, biometrics);

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pump();
    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pump();

    expect(biometrics.authenticationCalls, 1);
    expect(auth.roleChecks, 0);
    expect(find.byType(HomeScreen), findsNothing);

    result.complete(true);
    await tester.pumpAndSettle();
    expect(auth.roleChecks, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'Biometric exception opens password login and keeps the session',
    (tester) async {
      final auth = FakeAuthService(savedSession: true);
      final biometrics = FakeBiometricService(
        authenticationError: PlatformException(
          code: 'authentication_cancelled',
        ),
      );
      await _pumpLogin(tester, auth, biometrics);

      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pumpAndSettle();

      expect(auth.roleChecks, 0);
      expect(auth.signOutCalls, 0);
      expect(auth.hasCurrentUser, isTrue);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(auth.roleChecks, 0);
      expect(auth.signOutCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rejected fallback password cannot use the saved session to enter Home',
    (tester) async {
      final auth = FakeAuthService(
        savedSession: true,
        passwordError: 'Incorrect email or password. Please try again.',
      );
      await _pumpLogin(
        tester,
        auth,
        FakeBiometricService(authenticated: false),
      );

      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'student@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'wrong-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Incorrect email or password. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
      expect(auth.roleChecks, 0);
      expect(auth.signOutCalls, 0);
      expect(auth.hasCurrentUser, isTrue);
    },
  );

  testWidgets(
    'Home arrow signs out, clears the stack, and restores password login',
    (tester) async {
      final auth = FakeAuthService(savedSession: true);
      final biometrics = FakeBiometricService();
      await _pumpLogin(tester, auth, biometrics);
      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(auth.hasCurrentUser, isFalse);
      expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );

      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(auth.roleChecks, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed sign-out keeps Home open and reports the error', (
    tester,
  ) async {
    final auth = FakeAuthService(savedSession: true, failSignOut: true);
    await _pumpLogin(tester, auth, FakeBiometricService());
    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(auth.hasCurrentUser, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Unable to sign out. Please try again.'), findsOneWidget);
  });
}

Future<void> _pumpLogin(
  WidgetTester tester,
  FakeAuthService auth,
  FakeBiometricService biometrics,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final viewModel = AuthViewModel(
    authService: auth,
    biometricService: biometrics,
  );
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LoginScreen(
        viewModel: viewModel,
        homeBuilder: (context) => HomeScreen(
          authService: auth,
          lostReportRepository: LostReportRepository(
            firestore: FakeFirestore(),
          ),
        ),
      ),
    ),
  );
}
