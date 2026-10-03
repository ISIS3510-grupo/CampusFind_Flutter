import 'dart:async';

import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/analytics/analytics_dependencies.dart';
import 'package:campusfind_flutter/features/analytics/data/report_registration_time_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_registration_time_summary.dart';
import 'package:campusfind_flutter/features/analytics/presentation/report_registration_time_panel.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/report_registration_time_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';
import 'support/registration_time_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  late FakeRegistrationTimeRepository repository;
  late FakeRegistrationTimeAggregationService aggregation;
  late ReportRegistrationTimeViewModel model;
  setUp(() {
    repository = FakeRegistrationTimeRepository();
    aggregation = FakeRegistrationTimeAggregationService();
    model = ReportRegistrationTimeViewModel(
      repository: repository,
      aggregationService: aggregation,
    );
  });
  tearDown(() => model.dispose());

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              child: ReportRegistrationTimePanel(viewModel: model),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders overall, type averages in seconds and sample counts', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('0.97 s'), findsOneWidget);
    expect(find.text('0.84 s'), findsOneWidget);
    expect(find.text('1.24 s'), findsOneWidget);
    expect(find.text('2 samples'), findsOneWidget);
    expect(find.text('1 sample'), findsOneWidget);
    expect(find.text('Based on 3 successful registrations'), findsOneWidget);
  });

  testWidgets('empty data does not show zero-second averages', (tester) async {
    repository.summary = registrationSummary(lostCount: 0, foundCount: 0);
    await pump(tester);
    expect(find.text('No registration measurements yet'), findsOneWidget);
    expect(find.text('0.00 s'), findsNothing);
    expect(find.byKey(const ValueKey('registration-average')), findsNothing);
  });

  for (final lostMissing in [true, false]) {
    testWidgets(
      'missing ${lostMissing ? 'lost' : 'found'} group has no fabricated mean',
      (tester) async {
        repository.summary = registrationSummary(
          lostCount: lostMissing ? 0 : 1,
          foundCount: lostMissing ? 1 : 0,
        );
        await pump(tester);
        expect(find.text('No measurements yet'), findsOneWidget);
        expect(find.text('0 samples'), findsOneWidget);
        expect(find.text('0.00 s'), findsNothing);
        expect(find.text('Based on 1 successful registration'), findsOneWidget);
      },
    );
  }

  testWidgets('loading does not show empty state or enable refresh', (
    tester,
  ) async {
    repository.pending = Completer<ReportRegistrationTimeSummary>();
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No registration measurements yet'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    repository.pending!.complete(repository.summary);
    await tester.pumpAndSettle();
  });

  testWidgets('missing aggregate offers refresh and displays its result', (
    tester,
  ) async {
    repository.error = ReportRegistrationTimeNotGeneratedException();
    await pump(tester);
    expect(
      find.text('Registration time analytics have not been generated yet.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Refresh analytics'));
    await tester.pumpAndSettle();
    expect(aggregation.calls, 1);
    expect(find.text('Based on 5 successful registrations'), findsOneWidget);
    expect(
      find.text('Registration time analytics have not been generated yet.'),
      findsNothing,
    );
  });

  testWidgets(
    'refresh preserves data, disables repeated taps and handles failure',
    (tester) async {
      aggregation.pending = Completer<ReportRegistrationTimeSummary>();
      await pump(tester);
      await tester.tap(find.text('Refresh analytics'));
      await tester.pump();
      expect(find.text('Based on 3 successful registrations'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Refresh analytics'));
      expect(aggregation.calls, 1);
      aggregation.pending!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Unable to refresh registration time analytics. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Based on 3 successful registrations'), findsOneWidget);
      aggregation.pending = null;
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(find.text('Based on 5 successful registrations'), findsOneWidget);
    },
  );

  testWidgets('narrow viewport and large text have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, scale: 1.8);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuild does not reload or dispose caller-owned model', (
    tester,
  ) async {
    await pump(tester);
    await pump(tester);
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox());
    await model.load();
    expect(repository.calls, 2);
  });

  testWidgets(
    'real repository and aggregation refresh Firestore samples into panel',
    (tester) async {
      final database = FakeFirestore(
        documents: {
          'performanceMetrics/1': {
            'metricType': 'report_registration',
            'platform': 'flutter',
            'reportType': 'lost',
            'durationMs': 842,
          },
          'performanceMetrics/2': {
            'metricType': 'report_registration',
            'platform': 'flutter',
            'reportType': 'found',
            'durationMs': 1240,
          },
        },
      );
      final realModel = createReportRegistrationTimeViewModel(
        firestore: database,
      );
      addTearDown(realModel.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportRegistrationTimePanel(viewModel: realModel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(database.documentReads, ['analytics/reportRegistrationTime']);
      expect(database.queries, isEmpty);
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(find.text('1.04 s'), findsOneWidget);
      expect(find.text('0.84 s'), findsOneWidget);
      expect(find.text('1.24 s'), findsOneWidget);
      expect(find.text('Based on 2 successful registrations'), findsOneWidget);
      expect(
        database.documentWrites.single['path'],
        'analytics/reportRegistrationTime',
      );
      expect(
        database.documents['analytics/reportRegistrationTime']!['averageMs'],
        1041.0,
      );
    },
  );
}
