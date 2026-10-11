import 'dart:async';

import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/analytics/data/report_bottleneck_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/presentation/report_bottleneck_panel.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/report_bottleneck_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/analytics_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  late FakeReportBottleneckRepository repository;
  late FakeReportBottleneckAggregationService aggregation;
  late ReportBottleneckViewModel model;
  final now = DateTime.utc(2026, 9, 30, 12);

  setUp(() {
    repository = FakeReportBottleneckRepository();
    repository.summary = ReportBottleneckSummary.fromCounts({
      'reported': 8,
      'found': 3,
      'ready_for_pickup': 5,
      'claimed': 1,
    });
    aggregation = FakeReportBottleneckAggregationService();
    model = ReportBottleneckViewModel(
      repository: repository,
      aggregationService: aggregation,
      now: () => now,
    );
  });
  tearDown(() => model.dispose());

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ReportBottleneckPanel(viewModel: model),
          ),
        ),
      ),
    );
  }

  Finder countRow(String stage) =>
      find.byKey(ValueKey('bottleneck-count-$stage'));
  Finder highestStage() =>
      find.byKey(const ValueKey('bottleneck-highest-stage'));
  ElevatedButton refreshButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets(
    'initial loading is local to the panel and shows no fake counts',
    (tester) async {
      repository.pending = Completer<ReportBottleneckSummary>();
      await pumpPanel(tester);
      expect(find.text('Report bottleneck'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReportBottleneckPanel),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(countRow('reported'), findsNothing);
      expect(refreshButton(tester).onPressed, isNull);
      repository.pending!.complete(repository.summary);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('renders all four counts with readable labels', (tester) async {
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    const labels = {
      'reported': 'Reported',
      'found': 'Found',
      'ready_for_pickup': 'Ready for pickup',
      'claimed': 'Claimed',
    };
    for (final stage in labels.entries) {
      expect(
        find.descendant(
          of: countRow(stage.key),
          matching: find.text(stage.value),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: countRow(stage.key),
          matching: find.text('${repository.summary.counts[stage.key]}'),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('ready_for_pickup'), findsNothing);
  });

  testWidgets('displays the single highest stage', (tester) async {
    repository.summary = ReportBottleneckSummary.fromCounts({
      'ready_for_pickup': 6,
      'found': 2,
    });
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    expect(find.text('Most common bottleneck'), findsOneWidget);
    expect(tester.widget<Text>(highestStage()).data, 'Ready for pickup');
  });

  testWidgets('displays tied stages in readable form', (tester) async {
    repository.summary = ReportBottleneckSummary.fromCounts({
      'reported': 5,
      'found': 5,
    });
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(highestStage()).data, 'Reported, Found');
  });

  testWidgets('all zero counts display No stuck reports', (tester) async {
    repository.summary = ReportBottleneckSummary.fromCounts({});
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(4));
    expect(find.text('No stuck reports'), findsOneWidget);
  });

  testWidgets(
    'Refresh analytics invokes aggregation and immediately updates values',
    (tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(aggregation.calls, 1);
      expect(aggregation.receivedNow, now);
      expect(repository.calls, 1);
      expect(tester.widget<Text>(highestStage()).data, 'Claimed');
      expect(
        find.descendant(of: countRow('claimed'), matching: find.text('3')),
        findsOneWidget,
      );
    },
  );

  testWidgets('refresh disables the button and keeps previous counts visible', (
    tester,
  ) async {
    aggregation.pending = Completer<ReportBottleneckSummary>();
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh analytics'));
    await tester.pump();
    expect(refreshButton(tester).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.descendant(of: countRow('reported'), matching: find.text('8')),
      findsOneWidget,
    );
    await tester.tap(find.text('Refresh analytics'));
    expect(aggregation.calls, 1);
    aggregation.pending!.complete(aggregation.summary);
    await tester.pumpAndSettle();
    expect(refreshButton(tester).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'refresh error stays inside the panel alongside previous values',
    (tester) async {
      aggregation.error = StateError('Private backend details');
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ReportBottleneckPanel),
          matching: find.text('Unable to refresh analytics. Please try again.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: countRow('reported'), matching: find.text('8')),
        findsOneWidget,
      );
      expect(find.text('Private backend details'), findsNothing);
      expect(refreshButton(tester).onPressed, isNotNull);
      aggregation.error = null;
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to refresh analytics. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'missing aggregate leaves Refresh available to generate analytics',
    (tester) async {
      repository.error = ReportBottleneckNotGeneratedException();
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('No analytics have been generated yet.'),
        findsOneWidget,
      );
      expect(refreshButton(tester).onPressed, isNotNull);
      expect(countRow('reported'), findsNothing);
      await tester.tap(find.text('Refresh analytics'));
      await tester.pumpAndSettle();
      expect(find.text('No analytics have been generated yet.'), findsNothing);
      expect(countRow('reported'), findsOneWidget);
    },
  );

  testWidgets('never displays internal missing timestamp report IDs', (
    tester,
  ) async {
    repository.summary = ReportBottleneckSummary.fromCounts(
      {'found': 2},
      missingTimestampReportIds: ['private-report-id'],
    );
    await pumpPanel(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('private-report-id'), findsNothing);
    expect(find.textContaining('missingTimestampReportIds'), findsNothing);
    expect(countRow('found'), findsOneWidget);
  });

  testWidgets(
    'rebuilds do not reload and unmount leaves the injected model usable',
    (tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(400, 850);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await model.load();
      expect(repository.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small screen and enlarged text scroll without overflow', (
    tester,
  ) async {
    await pumpPanel(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Refresh analytics'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
