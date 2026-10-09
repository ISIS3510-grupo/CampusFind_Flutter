import 'dart:async';

import 'package:campusfind_flutter/features/analytics/services/report_registration_performance_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/registration_time_fakes.dart';

void main() {
  late FakeRegistrationMetricRepository repository;
  late _TestStopwatch stopwatch;
  late ReportRegistrationPerformanceTracker tracker;
  setUp(() {
    repository = FakeRegistrationMetricRepository();
    stopwatch = _TestStopwatch();
    tracker = ReportRegistrationPerformanceTracker(
      repository: repository,
      createStopwatch: () => stopwatch,
    );
  });

  for (final type in ['lost', 'found']) {
    test(
      '$type returns original result and records exactly one elapsed sample',
      () async {
        final result = Object();
        expect(
          await tracker.measure(
            reportType: type,
            operation: () async {
              expect(stopwatch.starts, 1);
              expect(stopwatch.stops, 0);
              stopwatch.milliseconds = 842;
              return result;
            },
          ),
          same(result),
        );
        expect(stopwatch.stops, 1);
        expect(repository.records, [
          {'reportType': type, 'durationMs': 842},
        ]);
      },
    );
  }

  for (final asynchronous in [false, true]) {
    test(
      '${asynchronous ? 'async' : 'sync'} failure preserves error and records nothing',
      () async {
        final error = StateError('registration failed');
        final stack = StackTrace.fromString('original backend stack');
        try {
          await tracker.measure<Object>(
            reportType: 'lost',
            operation: () {
              if (asynchronous) return Future.error(error, stack);
              Error.throwWithStackTrace(error, stack);
            },
          );
          fail('Expected original operation error');
        } catch (actual, actualStack) {
          expect(actual, same(error));
          expect(actualStack.toString(), contains('original backend stack'));
        }
        expect(stopwatch.stops, 1);
        expect(repository.records, isEmpty);
      },
    );
  }

  test('analytics failure does not fail registration', () async {
    repository.error = StateError('permission denied');
    expect(
      await tracker.measure(reportType: 'found', operation: () async => 'ok'),
      'ok',
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.records, hasLength(1));
  });

  test(
    'pending analytics never blocks result and late failure is contained',
    () async {
      repository.pending = Completer<void>();
      expect(
        await tracker.measure(reportType: 'lost', operation: () async => 'ok'),
        'ok',
      );
      expect(repository.pending!.isCompleted, isFalse);
      repository.pending!.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('invalid type rejected before operation or timing', () async {
    var operations = 0;
    for (final type in ['', 'other', 'Lost']) {
      await expectLater(
        tracker.measure(
          reportType: type,
          operation: () async {
            operations++;
          },
        ),
        throwsArgumentError,
      );
    }
    expect(operations, 0);
    expect(stopwatch.starts, 0);
    expect(repository.records, isEmpty);
  });

  test(
    'required upload and backend confirmation are inside the timer',
    () async {
      final upload = Completer<void>();
      final backend = Completer<String>();
      final operation = tracker.measure(
        reportType: 'found',
        operation: () async {
          await upload.future;
          return backend.future;
        },
      );
      stopwatch.milliseconds = 842;
      upload.complete();
      await Future<void>.delayed(Duration.zero);
      expect(stopwatch.stops, 0);
      expect(repository.records, isEmpty);
      stopwatch.milliseconds = 1240;
      backend.complete('registered');
      expect(await operation, 'registered');
      expect(repository.records.single['durationMs'], 1240);
    },
  );

  test('nullable and void results supported', () async {
    expect(
      await tracker.measure<String?>(
        reportType: 'lost',
        operation: () async => null,
      ),
      isNull,
    );
    await tracker.measure<void>(reportType: 'found', operation: () async {});
    expect(repository.records, hasLength(2));
  });

  test('each measurement gets its own stopwatch', () async {
    final clocks = <_TestStopwatch>[];
    final separate = ReportRegistrationPerformanceTracker(
      repository: repository,
      createStopwatch: () {
        final clock = _TestStopwatch();
        clocks.add(clock);
        return clock;
      },
    );
    final first = Completer<void>();
    final pending = separate.measure(
      reportType: 'lost',
      operation: () => first.future,
    );
    clocks.first.milliseconds = 40;
    await separate.measure(
      reportType: 'found',
      operation: () async {
        clocks.last.milliseconds = 90;
      },
    );
    first.complete();
    await pending;
    expect(repository.records.map((r) => r['durationMs']), [90, 40]);
    expect(clocks.every((c) => c.starts == 1 && c.stops == 1), isTrue);
  });
}

class _TestStopwatch extends Fake implements Stopwatch {
  int milliseconds = 0;
  int starts = 0;
  int stops = 0;
  @override
  void start() => starts++;
  @override
  void stop() => stops++;
  @override
  int get elapsedMilliseconds => milliseconds;
}
