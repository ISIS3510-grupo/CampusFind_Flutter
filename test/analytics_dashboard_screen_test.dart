import 'dart:async';

import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/presentation/analytics_dashboard_screen.dart';
import 'package:campusfind_flutter/features/analytics/presentation/report_bottleneck_panel.dart';
import 'package:campusfind_flutter/features/analytics/presentation/report_registration_time_panel.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/report_bottleneck_view_model.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/analytics_fakes.dart';
import 'support/auth_fakes.dart';
import 'support/registration_time_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets(
    'dashboard contains bottleneck then registration time by default',
    (tester) async {
      final repository = FakeReportBottleneckRepository();
      final model = ReportBottleneckViewModel(repository: repository);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AnalyticsDashboardScreen(
            reportBottleneckViewModel: model,
            reportRegistrationTimeViewModel: testRegistrationTimeViewModel(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byType(ReportBottleneckPanel), findsOneWidget);
      expect(find.text('Report bottleneck'), findsOneWidget);
      expect(find.byType(ReportRegistrationTimePanel), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ReportRegistrationTimePanel)).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(ReportBottleneckPanel)).dy,
        ),
      );
      expect(
        tester
            .widget<AnalyticsDashboardScreen>(
              find.byType(AnalyticsDashboardScreen),
            )
            .additionalPanels,
        isEmpty,
      );
      expect(repository.calls, 1);
    },
  );

  testWidgets(
    'additional widgets render independently through panel loading and failure',
    (tester) async {
      final repository = FakeReportBottleneckRepository();
      repository.pending = Completer<ReportBottleneckSummary>();
      final model = ReportBottleneckViewModel(repository: repository);
      addTearDown(model.dispose);
      const marker = ValueKey('additional-widget');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AnalyticsDashboardScreen(
            reportBottleneckViewModel: model,
            reportRegistrationTimeViewModel: testRegistrationTimeViewModel(),
            additionalPanels: const [SizedBox(key: marker, height: 12)],
          ),
        ),
      );
      expect(find.byKey(marker), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(marker)).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(ReportRegistrationTimePanel)).dy,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(ReportBottleneckPanel),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      repository.pending!.completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(find.byKey(marker), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(marker)).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(ReportRegistrationTimePanel)).dy,
        ),
      );
      expect(find.text('Analytics'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReportBottleneckPanel),
          matching: find.text(
            'Unable to load report bottleneck analytics. Please try again.',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back signs out and replaces the whole stack with Login', (
    tester,
  ) async {
    final auth = FakeAuthService(savedSession: true);
    final model = ReportBottleneckViewModel(
      repository: FakeReportBottleneckRepository(),
    );
    addTearDown(model.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('Previous route')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => AnalyticsDashboardScreen(
          authService: auth,
          reportBottleneckViewModel: model,
          reportRegistrationTimeViewModel: testRegistrationTimeViewModel(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReportBottleneckPanel), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(auth.hasCurrentUser, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.widget<LoginScreen>(find.byType(LoginScreen)).authService,
      same(auth),
    );
    expect(
      find.byType(AnalyticsDashboardScreen, skipOffstage: false),
      findsNothing,
    );
    expect(find.text('Previous route', skipOffstage: false), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(await navigatorKey.currentState!.maybePop(), isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'back waits for sign-out and blocks repeated taps before the injected destination',
    (tester) async {
      final pending = Completer<void>();
      final auth = FakeAuthService(savedSession: true, pendingSignOut: pending);
      final model = ReportBottleneckViewModel(
        repository: FakeReportBottleneckRepository(),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AnalyticsDashboardScreen(
            authService: auth,
            reportBottleneckViewModel: model,
            reportRegistrationTimeViewModel: testRegistrationTimeViewModel(),
            loginBuilder: (context) =>
                const Scaffold(body: Text('Login destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
      expect(find.text('Login destination'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_back),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Back'));
      expect(auth.signOutCalls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      expect(
        find.byType(AnalyticsDashboardScreen, skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets('failed sign-out keeps analytics visible and allows retry', (
    tester,
  ) async {
    final auth = FakeAuthService(savedSession: true, failSignOut: true);
    final repository = FakeReportBottleneckRepository();
    final model = ReportBottleneckViewModel(repository: repository);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AnalyticsDashboardScreen(
          authService: auth,
          reportBottleneckViewModel: model,
          reportRegistrationTimeViewModel: testRegistrationTimeViewModel(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
    expect(find.byType(ReportBottleneckPanel), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Unable to sign out. Please try again.'), findsOneWidget);
    expect(auth.hasCurrentUser, isTrue);
    expect(repository.calls, 1);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back))
          .onPressed,
      isNotNull,
    );
    auth.failSignOut = false;
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 2);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
