import 'dart:async';

import 'package:campusfind_flutter/features/analytics/data/report_registration_time_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_registration_time_summary.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/report_registration_time_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/registration_time_fakes.dart';

void main() {
  late FakeRegistrationTimeRepository repository;
  late FakeRegistrationTimeAggregationService aggregation;
  late ReportRegistrationTimeViewModel model;
  final now = DateTime.utc(2026, 9, 30);
  setUp(() {
    repository = FakeRegistrationTimeRepository();
    aggregation = FakeRegistrationTimeAggregationService();
    model = ReportRegistrationTimeViewModel(
      repository: repository,
      aggregationService: aggregation,
      now: () => now,
    );
  });
  tearDown(() => model.dispose());

  test(
    'load only reads aggregate and notifies loading and completion',
    () async {
      final states = <bool>[];
      model.addListener(() => states.add(model.isLoading));
      await model.load();
      expect(states, [true, false]);
      expect(model.summary, same(repository.summary));
      expect(model.errorMessage, isNull);
      expect(aggregation.calls, 0);
    },
  );

  test(
    'missing aggregate has clear message and no fabricated summary',
    () async {
      repository.error = ReportRegistrationTimeNotGeneratedException();
      await model.load();
      expect(model.summary, isNull);
      expect(
        model.errorMessage,
        'Registration time analytics have not been generated yet.',
      );
      expect(model.isLoading, isFalse);
    },
  );

  test('load failure can retry', () async {
    repository.error = StateError('offline');
    await model.load();
    expect(model.errorMessage, contains('Unable to load'));
    repository.error = null;
    await model.load();
    expect(model.errorMessage, isNull);
    expect(model.summary, same(repository.summary));
  });

  test(
    'refresh updates only after aggregation succeeds and supplies now',
    () async {
      aggregation.pending = Completer<ReportRegistrationTimeSummary>();
      final refresh = model.refresh();
      expect(model.isRefreshing, isTrue);
      expect(model.summary, isNull);
      aggregation.pending!.complete(aggregation.summary);
      await refresh;
      expect(aggregation.receivedNow, now);
      expect(model.summary, same(aggregation.summary));
      expect(model.isRefreshing, isFalse);
      expect(repository.calls, 0);
    },
  );

  test('refresh failure retains previous data and allows retry', () async {
    await model.load();
    aggregation.error = StateError('permission denied');
    await model.refresh();
    expect(model.summary, same(repository.summary));
    expect(model.errorMessage, contains('Unable to refresh'));
    expect(model.isRefreshing, isFalse);
    aggregation.error = null;
    await model.refresh();
    expect(model.errorMessage, isNull);
    expect(model.summary, same(aggregation.summary));
  });

  for (final refreshing in [false, true]) {
    test(
      'duplicate operations blocked while ${refreshing ? 'refreshing' : 'loading'}',
      () async {
        final pending = Completer<ReportRegistrationTimeSummary>();
        if (refreshing) {
          aggregation.pending = pending;
        } else {
          repository.pending = pending;
        }
        final operation = refreshing ? model.refresh() : model.load();
        await model.refresh();
        await model.load();
        expect(repository.calls, refreshing ? 0 : 1);
        expect(aggregation.calls, refreshing ? 1 : 0);
        pending.complete(registrationSummary());
        await operation;
      },
    );
    for (final fail in [false, true]) {
      test(
        'dispose during ${refreshing ? 'refresh' : 'load'} safely handles ${fail ? 'error' : 'success'}',
        () async {
          final disposable = ReportRegistrationTimeViewModel(
            repository: repository,
            aggregationService: aggregation,
          );
          final pending = Completer<ReportRegistrationTimeSummary>();
          if (refreshing) {
            aggregation.pending = pending;
          } else {
            repository.pending = pending;
          }
          var notifications = 0;
          disposable.addListener(() => notifications++);
          final operation = refreshing
              ? disposable.refresh()
              : disposable.load();
          disposable.dispose();
          if (fail) {
            pending.completeError(StateError('offline'));
          } else {
            pending.complete(registrationSummary());
          }
          await operation;
          await disposable.load();
          await disposable.refresh();
          expect(notifications, 1);
          expect(disposable.summary, isNull);
        },
      );
    }
  }
}
