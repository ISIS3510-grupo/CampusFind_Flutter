import 'package:campusfind_flutter/features/analytics/services/offline_sync_time_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/offline_sync_fakes.dart';

void main() {
  late FakeOfflineSyncMetricRepository repository;
  late TestStopwatch stopwatch;
  late DateTime now;
  late OfflineSyncTimeTracker tracker;

  setUp(() {
    repository = FakeOfflineSyncMetricRepository();
    stopwatch = TestStopwatch();
    now = DateTime(2026, 1, 1, 10);
    tracker = OfflineSyncTimeTracker(
      repository: repository,
      createStopwatch: () => stopwatch,
      now: () => now,
    );
  });

  test('records the elapsed time, report count and offline time', () async {
    tracker.markOffline();
    now = now.add(const Duration(minutes: 10));

    final session = tracker.beginRecovery();
    expect(stopwatch.starts, 1);
    stopwatch.milliseconds = 4200;
    session.complete(reportCount: 3);
    await pumpEventQueue();

    expect(stopwatch.stops, 1);
    expect(repository.records, [
      {
        'uid': 'student-1',
        'durationMs': 4200,
        'reportCount': 3,
        'offlineDurationMs': const Duration(minutes: 10).inMilliseconds,
      },
    ]);
  });

  test('only the first markOffline of an offline period counts', () async {
    tracker.markOffline();
    now = now.add(const Duration(minutes: 5));
    tracker.markOffline();
    now = now.add(const Duration(minutes: 5));

    tracker.beginRecovery().complete(reportCount: 1);
    await pumpEventQueue();

    expect(
      repository.records.single['offlineDurationMs'],
      const Duration(minutes: 10).inMilliseconds,
    );
  });

  test('offline time is unknown when the drop was never seen', () async {
    tracker.beginRecovery().complete(reportCount: 1);
    await pumpEventQueue();

    expect(repository.records.single['offlineDurationMs'], isNull);
  });

  test('the next recovery does not reuse the previous offline time', () async {
    tracker.markOffline();
    tracker.beginRecovery().complete(reportCount: 1);
    tracker.beginRecovery().complete(reportCount: 1);
    await pumpEventQueue();

    expect(repository.records.last['offlineDurationMs'], isNull);
  });

  test('a session records once, and nothing without reports', () async {
    final session = tracker.beginRecovery();
    session.complete(reportCount: 0);
    expect(repository.records, isEmpty);

    session.complete(reportCount: 2);
    session.complete(reportCount: 2);
    await pumpEventQueue();

    expect(repository.records, hasLength(1));
    expect(stopwatch.stops, 1);
  });

  test('a failed write is contained', () async {
    repository.recordError = StateError('offline');

    tracker.beginRecovery().complete(reportCount: 1);
    await pumpEventQueue();

    expect(repository.records, hasLength(1));
  });
}
