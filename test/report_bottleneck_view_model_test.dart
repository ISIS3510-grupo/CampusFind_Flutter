import 'dart:async';

import 'package:campusfind_flutter/features/analytics/data/report_bottleneck_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/report_bottleneck_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/analytics_fakes.dart';
import 'support/firestore_fakes.dart';

void main() {
  late FakeReportBottleneckRepository repository;
  late FakeReportBottleneckAggregationService aggregation;
  late ReportBottleneckViewModel model;
  final now = DateTime.utc(2026, 9, 30, 12);
  var disposed = false;

  setUp(() {
    repository = FakeReportBottleneckRepository();
    aggregation = FakeReportBottleneckAggregationService();
    model = ReportBottleneckViewModel(
      repository: repository,
      aggregationService: aggregation,
      now: () => now,
    );
    disposed = false;
  });
  tearDown(() {
    if (!disposed) model.dispose();
  });

  test('initial state is idle without data or errors', () {
    expect(model.summary, isNull);
    expect(model.isLoading, isFalse);
    expect(model.isRefreshing, isFalse);
    expect(model.errorMessage, isNull);
    expect(repository.calls, 0);
  });

  test('loading exposes state and notifies on start and completion', () async {
    repository.pending = Completer<ReportBottleneckSummary>();
    final states = <bool>[];
    model.addListener(() => states.add(model.isLoading));
    final loading = model.load();
    expect(model.isLoading, isTrue);
    expect(model.summary, isNull);
    expect(model.errorMessage, isNull);
    repository.pending!.complete(repository.summary);
    await loading;
    expect(states, [true, false]);
  });

  test('success stores the exact repository summary', () async {
    await model.load();
    expect(model.summary, same(repository.summary));
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
    expect(repository.calls, 1);
    expect(aggregation.calls, 0);
  });

  test('failure exposes an error without fallback data', () async {
    repository.error = StateError('Read failed');
    await model.load();
    expect(model.summary, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNotEmpty);
  });

  test('retry clears the error before completing successfully', () async {
    repository.error = StateError('Read failed');
    await model.load();
    repository.error = null;
    repository.pending = Completer<ReportBottleneckSummary>();
    final retry = model.load();
    expect(model.errorMessage, isNull);
    expect(model.isLoading, isTrue);
    repository.pending!.complete(repository.summary);
    await retry;
    expect(model.summary, same(repository.summary));
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
    expect(repository.calls, 2);
  });

  test('a failed reload clears the previous successful summary', () async {
    await model.load();
    repository.error = StateError('Read failed');
    await model.load();
    expect(model.summary, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNotEmpty);
  });

  test('overlapping loads do not duplicate repository reads', () async {
    repository.pending = Completer<ReportBottleneckSummary>();
    final loading = model.load();
    await model.load();
    expect(repository.calls, 1);
    repository.pending!.complete(repository.summary);
    await loading;
  });

  for (final fails in [false, true]) {
    test(
      'dispose prevents notifications after ${fails ? 'failure' : 'success'}',
      () async {
        repository.pending = Completer<ReportBottleneckSummary>();
        var notifications = 0;
        model.addListener(() => notifications++);
        final loading = model.load();
        model.dispose();
        disposed = true;
        if (fails) {
          repository.pending!.completeError(StateError('Read failed'));
        } else {
          repository.pending!.complete(repository.summary);
        }
        await loading;
        await model.load();
        expect(notifications, 1);
        expect(repository.calls, 1);
        expect(model.summary, isNull);
        expect(model.errorMessage, isNull);
      },
    );
  }
  test('normal load reads only the aggregate document', () async {
    final database = FakeFirestore(
      documents: {
        'analytics/reportBottleneck': {'found': 5},
      },
    );
    final viewModel = ReportBottleneckViewModel(
      repository: ReportBottleneckRepository(firestore: database),
      aggregationService: aggregation,
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();
    expect(viewModel.summary?.counts['found'], 5);
    expect(database.documentReads, ['analytics/reportBottleneck']);
    expect(database.queries, isEmpty);
    expect(database.documentWrites, isEmpty);
    expect(aggregation.calls, 0);
  });

  test(
    'missing aggregate is distinguishable and can be generated by refresh',
    () async {
      repository.error = ReportBottleneckNotGeneratedException();
      await model.load();
      expect(model.summary, isNull);
      expect(model.isLoading, isFalse);
      expect(model.errorMessage, 'No analytics have been generated yet.');
      await model.refresh();
      expect(model.summary, same(aggregation.summary));
      expect(model.errorMessage, isNull);
      expect(model.isRefreshing, isFalse);
    },
  );

  test(
    'refresh uses injected clock and immediately stores returned summary',
    () async {
      await model.refresh();
      expect(aggregation.calls, 1);
      expect(aggregation.receivedNow, now);
      expect(repository.calls, 0);
      expect(model.summary, same(aggregation.summary));
      expect(model.isRefreshing, isFalse);
      expect(model.isLoading, isFalse);
    },
  );

  test('refresh preserves existing values while pending and notifies state changes', () async {
    await model.load();
    aggregation.pending = Completer<ReportBottleneckSummary>();
    final states = <bool>[];
    model.addListener(() => states.add(model.isRefreshing));
    final refreshing = model.refresh();
    expect(model.summary, same(repository.summary));
    expect(model.isRefreshing, isTrue);
    expect(model.isLoading, isFalse);
    aggregation.pending!.complete(aggregation.summary);
    await refreshing;
    expect(model.summary, same(aggregation.summary));
    expect(states, [true, false]);
  });

  test(
    'refresh failure preserves previous values and resets refreshing',
    () async {
      await model.load();
      aggregation.error = StateError('Offline');
      await model.refresh();
      expect(model.summary, same(repository.summary));
      expect(
        model.errorMessage,
        'Unable to refresh analytics. Please try again.',
      );
      expect(model.isRefreshing, isFalse);
    },
  );

  test(
    'refresh failure without previous values does not invent data',
    () async {
      aggregation.error = StateError('Offline');
      await model.refresh();
      expect(model.summary, isNull);
      expect(model.errorMessage, isNotEmpty);
      expect(model.isRefreshing, isFalse);
    },
  );

  test('retry clears refresh error and replaces summary on success', () async {
    aggregation.error = StateError('Offline');
    await model.refresh();
    aggregation.error = null;
    aggregation.pending = Completer<ReportBottleneckSummary>();
    final retry = model.refresh();
    expect(model.errorMessage, isNull);
    aggregation.pending!.complete(aggregation.summary);
    await retry;
    expect(model.summary, same(aggregation.summary));
    expect(model.isRefreshing, isFalse);
    expect(aggregation.calls, 2);
  });

  test(
    'duplicate refresh and load during refresh cannot start extra requests',
    () async {
      aggregation.pending = Completer<ReportBottleneckSummary>();
      final refreshing = model.refresh();
      await model.refresh();
      await model.load();
      expect(aggregation.calls, 1);
      expect(repository.calls, 0);
      aggregation.pending!.complete(aggregation.summary);
      await refreshing;
    },
  );

  test('refresh during initial load is blocked', () async {
    repository.pending = Completer<ReportBottleneckSummary>();
    final loading = model.load();
    await model.refresh();
    expect(aggregation.calls, 0);
    repository.pending!.complete(repository.summary);
    await loading;
  });

  for (final fails in [false, true]) {
    test(
      'dispose during refresh prevents late ${fails ? 'errors' : 'results'}',
      () async {
        aggregation.pending = Completer<ReportBottleneckSummary>();
        var notifications = 0;
        model.addListener(() => notifications++);
        final refreshing = model.refresh();
        model.dispose();
        disposed = true;
        if (fails) {
          aggregation.pending!.completeError(StateError('Offline'));
        } else {
          aggregation.pending!.complete(aggregation.summary);
        }
        await refreshing;
        await model.refresh();
        expect(notifications, 1);
        expect(model.summary, isNull);
        expect(model.errorMessage, isNull);
        expect(aggregation.calls, 1);
      },
    );
  }
}
