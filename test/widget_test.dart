import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/auth/data/biometric_service.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Uses the SDK font so text has normal Android dimensions in tests.
    final packageConfig = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await packageConfig.readAsString())['packages'] as List;
    final flutterPackage = packages.firstWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterRoot = packageConfig.uri.resolve(
      '${flutterPackage['rootUri']}/',
    );
    for (final font in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final fontFile = File.fromUri(
        flutterRoot.resolve(
          '../../bin/cache/artifacts/material_fonts/${font.value}',
        ),
      );
      final fontLoader = FontLoader(font.key);
      fontLoader.addFont(
        fontFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await fontLoader.load();
    }
  });

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

    final auth = _FakeAuthService();
    final biometrics = _FakeBiometricService();
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

  testWidgets('Home displays the S02 content and inactive navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 42);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeScreen(foundItemScreenBuilder: _foundItemForm),
      ),
    );

    for (final text in [
      'Lost & Found',
      'What do you need?',
      'Search found items',
      'I found an item',
      'My active report',
      'Scientific calculator',
      'Lost in ML · 2 days ago',
      'Possible match',
    ]) {
      expect(find.text(text), findsOneWidget);
    }

    for (final text in ['Search found items', 'Search', 'Profile']) {
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
    expect(find.text('My active report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saved student session opens Home after biometric success', (
    tester,
  ) async {
    final auth = _FakeAuthService(savedSession: true);
    final biometrics = _FakeBiometricService();
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
      final auth = _FakeAuthService(savedSession: true);
      final biometrics = _FakeBiometricService(authenticated: false);
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

      // Ingresar correo y contraseña en el diálogo de inicio de sesión
      final textFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );

      await tester.enterText(textFields.at(0), 'estudiante@uniandes.edu.co');
      await tester.pump();
      await tester.enterText(textFields.at(1), 'Password123!');
      await tester.pump();

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
    final auth = _FakeAuthService(savedSession: true);
    final biometrics = _FakeBiometricService(available: false);
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
    final auth = _FakeAuthService(
      savedSession: true,
      roleError: 'This account does not have student access.',
    );
    await _pumpLogin(tester, auth, _FakeBiometricService());

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
    final auth = _FakeAuthService(savedSession: true);
    final biometrics = _FakeBiometricService(pendingResult: result);
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
      final auth = _FakeAuthService(savedSession: true);
      final biometrics = _FakeBiometricService(
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
      final auth = _FakeAuthService(
        savedSession: true,
        passwordError: 'Incorrect email or password. Please try again.',
      );
      await _pumpLogin(
        tester,
        auth,
        _FakeBiometricService(authenticated: false),
      );

      await tester.tap(find.text('Enter with Uniandes'));
      await tester.pumpAndSettle();

      final textFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );

      await tester.enterText(textFields.at(0), 'estudiante@uniandes.edu.co');
      await tester.pump();
      await tester.enterText(textFields.at(1), 'wrong-password');
      await tester.pump();

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
      final auth = _FakeAuthService(savedSession: true);
      final biometrics = _FakeBiometricService();
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
    final auth = _FakeAuthService(savedSession: true, failSignOut: true);
    await _pumpLogin(tester, auth, _FakeBiometricService());
    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(auth.hasCurrentUser, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Unable to sign out. Please try again.'), findsOneWidget);
  });

  testWidgets('I found an item opens the found item form', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(foundItemScreenBuilder: _foundItemForm),
      ),
    );

    await tester.tap(find.text('I found an item'));
    await tester.pumpAndSettle();

    expect(find.text('Found item form'), findsOneWidget);
  });
}

Future<void> _pumpLogin(
  WidgetTester tester,
  _FakeAuthService auth,
  _FakeBiometricService biometrics,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LoginScreen(authService: auth, biometricService: biometrics),
    ),
  );
}

// These services keep the widget tests independent of Firebase and the sensor.
class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.savedSession = false,
    this.roleError,
    this.passwordError,
    this.failSignOut = false,
  });

  bool savedSession;
  final String? roleError;
  final String? passwordError;
  final bool failSignOut;
  int roleChecks = 0;
  int passwordCalls = 0;
  int signOutCalls = 0;

  @override
  bool get hasCurrentUser => savedSession;

  @override
  Future<String?> verifyStudentRole() async {
    roleChecks++;
    return roleError;
  }

  @override
  Future<String?> signInStudent(String email, String password) async {
    passwordCalls++;
    if (passwordError != null) return passwordError;
    savedSession = true;
    return verifyStudentRole();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw StateError('Sign-out failed');
    savedSession = false;
  }
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({
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

// Stands in for the Firebase-backed found item form in widget tests.
Widget _foundItemForm(BuildContext context) => const Text('Found item form');
