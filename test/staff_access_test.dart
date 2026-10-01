import 'dart:async';

import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/analytics/analytics_dependencies.dart';
import 'package:campusfind_flutter/features/analytics/presentation/analytics_dashboard_screen.dart';
import 'package:campusfind_flutter/features/analytics/presentation/report_bottleneck_panel.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/auth/viewmodel/auth_view_model.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/firestore_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  late FakeAuthService auth;
  late FakeBiometricService biometrics;
  late FakeFirestore database;
  var homeBuilds = 0;

  setUp(() {
    auth = FakeAuthService();
    biometrics = FakeBiometricService();
    database = FakeFirestore(
      documents: {
        'analytics/reportBottleneck': {
          'reported': 8,
          'found': 3,
          'ready_for_pickup': 5,
          'claimed': 1,
        },
      },
    );
    homeBuilds = 0;
  });

  Future<void> openStaffForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = AuthViewModel(
      authService: auth,
      biometricService: biometrics,
    );
    final analytics = createReportBottleneckViewModel(firestore: database);
    addTearDown(model.dispose);
    addTearDown(analytics.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginScreen(
          viewModel: model,
          homeBuilder: (context) {
            homeBuilds++;
            return const Scaffold(body: Text('Student destination'));
          },
          staffDashboardBuilder: (context) =>
              AnalyticsDashboardScreen(reportBottleneckViewModel: analytics),
        ),
      ),
    );
    await tester.tap(find.text('Staff access'));
    await tester.pumpAndSettle();
  }

  Future<void> enterCredentials(
    WidgetTester tester, {
    String password = 'entered-password',
  }) async {
    await tester.enterText(
      find.byType(TextField).first,
      'staff@uniandes.edu.co',
    );
    await tester.enterText(find.byType(TextField).last, password);
  }

  testWidgets(
    'Staff Access reuses one form and submits the currently entered credentials',
    (tester) async {
      await openStaffForm(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Staff sign in'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await enterCredentials(tester, password: 'old-password');
      await tester.enterText(
        find.byType(TextField).first,
        'another-admin@uniandes.edu.co',
      );
      await tester.enterText(find.byType(TextField).last, 'new-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(auth.lastAdminEmail, 'another-admin@uniandes.edu.co');
      expect(auth.lastAdminPassword, 'new-password');
      expect(auth.adminCalls, 1);
      expect(auth.passwordCalls, 0);
      expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen, skipOffstage: false), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(homeBuilds, 0);
      expect(
        Navigator.of(tester.element(find.byType(AnalyticsDashboardScreen)))
            .canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'opening the staff dashboard loads only the precomputed aggregate',
    (tester) async {
      await openStaffForm(tester);
      await enterCredentials(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportBottleneckPanel), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(database.documentReads, ['analytics/reportBottleneck']);
      expect(database.queries, isEmpty);
      expect(database.documentWrites, isEmpty);
    },
  );

  testWidgets(
    'missing aggregate offers Refresh and aggregates only after the tap',
    (tester) async {
      database.documents.clear();
      await openStaffForm(tester);
      await enterCredentials(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.text('No analytics have been generated yet.'),
        findsOneWidget,
      );
      expect(database.queries, isEmpty);
      expect(database.documentWrites, isEmpty);
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(database.queries, [
        {'collection': 'lostReports'},
      ]);
      expect(
        database.documentWrites.single['path'],
        'analytics/reportBottleneck',
      );
      expect(find.text('No stuck reports'), findsOneWidget);
      expect(find.text('No analytics have been generated yet.'), findsNothing);
    },
  );

  for (final roleFailure in [false, true]) {
    testWidgets(
      '${roleFailure ? 'student role' : 'invalid password'} stays on Login and cannot build dashboard',
      (tester) async {
        if (roleFailure) {
          auth.adminRoleError = 'This account does not have staff access.';
        } else {
          auth.adminPasswordError =
              'Incorrect email or password. Please try again.';
        }
        await openStaffForm(tester);
        await enterCredentials(tester);
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AnalyticsDashboardScreen), findsNothing);
        expect(find.byType(HomeScreen), findsNothing);
        expect(
          find.text(
            roleFailure ? auth.adminRoleError! : auth.adminPasswordError!,
          ),
          findsOneWidget,
        );
        expect(database.documentReads, isEmpty);
        expect(database.queries, isEmpty);
        expect(auth.savedSession, isFalse);
        expect(homeBuilds, 0);
      },
    );
  }

  testWidgets('failed Staff Access can retry with the same fields', (
    tester,
  ) async {
    auth.adminPasswordError = 'Incorrect email or password. Please try again.';
    await openStaffForm(tester);
    await enterCredentials(tester, password: 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'staff@uniandes.edu.co',
    );
    auth.adminPasswordError = null;
    await tester.enterText(find.byType(TextField).last, 'correct');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(auth.adminCalls, 2);
    expect(auth.lastAdminPassword, 'correct');
    expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
  });

  testWidgets(
    'staff always requires credentials even when a session already exists',
    (tester) async {
      auth.savedSession = true;
      await openStaffForm(tester);
      expect(find.text('Staff sign in'), findsOneWidget);
      expect(biometrics.authenticationCalls, 0);
      expect(auth.adminCalls, 0);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.text('Please enter your email and password.'),
        findsOneWidget,
      );
      expect(auth.adminCalls, 0);
      expect(find.byType(AnalyticsDashboardScreen), findsNothing);
    },
  );

  testWidgets(
    'pending staff login disables submission and prevents duplicates',
    (tester) async {
      auth.pendingAdmin = Completer<String?>();
      await openStaffForm(tester);
      await enterCredentials(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Staff access'),
            )
            .onPressed,
        isNull,
      );
      expect(auth.adminCalls, 1);
      auth.pendingAdmin!.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
    },
  );
}
