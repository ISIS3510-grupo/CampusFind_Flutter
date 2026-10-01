import 'dart:async';

import 'package:campusfind_flutter/features/analytics/data/report_bottleneck_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/analytics_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Repository repository;
  late AnalyticsViewModel model;
  var disposed = false;

  setUp(() {
    repository = _Repository();
    model = AnalyticsViewModel(repository: repository);
    disposed = false;
  });
  tearDown(() {
    if (!disposed) model.dispose();
  });

  test('initial state is idle without data or errors', () {
    expect(model.bottleneckSummary, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
    expect(repository.calls, 0);
  });

  test('loading exposes state and notifies on start and completion', () async {
    repository.pending = Completer<ReportBottleneckSummary>();
    final states = <bool>[];
    model.addListener(() => states.add(model.isLoading));
    final loading = model.loadReportBottleneck();
    expect(model.isLoading, isTrue);
    expect(model.bottleneckSummary, isNull);
    expect(model.errorMessage, isNull);
    repository.pending!.complete(repository.summary);
    await loading;
    expect(states, [true, false]);
  });

  test('success stores the exact repository summary', () async {
    await model.loadReportBottleneck();
    expect(model.bottleneckSummary, same(repository.summary));
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
    expect(repository.calls, 1);
  });

  test('failure exposes an error without fallback data', () async {
    repository.error = StateError('Read failed');
    await model.loadReportBottleneck();
    expect(model.bottleneckSummary, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNotEmpty);
  });

  test('retry clears the error before completing successfully', () async {
    repository.error = StateError('Read failed');
    await model.loadReportBottleneck();
    repository.error = null;
    repository.pending = Completer<ReportBottleneckSummary>();
    final retry = model.loadReportBottleneck();
    expect(model.errorMessage, isNull);
    expect(model.isLoading, isTrue);
    repository.pending!.complete(repository.summary);
    await retry;
    expect(model.bottleneckSummary, same(repository.summary));
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
    expect(repository.calls, 2);
  });

  test('a failed refresh clears the previous successful summary', () async {
    await model.loadReportBottleneck();
    repository.error = StateError('Read failed');
    await model.loadReportBottleneck();
    expect(model.bottleneckSummary, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNotEmpty);
  });

  test('overlapping loads do not duplicate repository reads', () async {
    repository.pending = Completer<ReportBottleneckSummary>();
    final loading = model.loadReportBottleneck();
    await model.loadReportBottleneck();
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
        final loading = model.loadReportBottleneck();
        model.dispose();
        disposed = true;
        if (fails) {
          repository.pending!.completeError(StateError('Read failed'));
        } else {
          repository.pending!.complete(repository.summary);
        }
        await loading;
        await model.loadReportBottleneck();
        expect(notifications, 1);
        expect(repository.calls, 1);
        expect(model.bottleneckSummary, isNull);
        expect(model.errorMessage, isNull);
      },
    );
  }
}

class _Repository extends ReportBottleneckRepository {
  final summary = ReportBottleneckSummary.fromCounts({'reported': 8});
  Object? error;
  Completer<ReportBottleneckSummary>? pending;
  int calls = 0;

  @override
  Future<ReportBottleneckSummary> getSummary() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? summary : await pending!.future;
  }
}
