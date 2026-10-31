import 'dart:async';

import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/analytics/services/offline_sync_time_tracker.dart';
import 'package:campusfind_flutter/features/reports/data/pending_report_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/offline_sync_fakes.dart';
import 'fake_lost_report_repository.dart';

class _StreamConnectivity implements ConnectivityService {
  final controller = StreamController<bool>();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => controller.stream;
}

void main() {
  test('syncs when the connection returns or the student signs in', () async {
    final repository = FakeLostReportRepository();
    final connectivity = _StreamConnectivity();
    final signedIn = StreamController<bool>();
    final sync = PendingReportSync(
      repository: repository,
      connectivity: connectivity,
      signedInChanges: signedIn.stream,
      retryDelays: const [],
    )..start();

    connectivity.controller.add(false);
    signedIn.add(false);
    await pumpEventQueue();
    expect(repository.syncCalls, 0);

    connectivity.controller.add(true);
    await pumpEventQueue();
    signedIn.add(true);
    await pumpEventQueue();
    expect(repository.syncCalls, 2);

    await sync.stop();
  });

  test('retries while reports are still waiting', () async {
    final repository = FakeLostReportRepository()..waitingAfterSync = [2, 1];
    final connectivity = _StreamConnectivity();
    final sync = PendingReportSync(
      repository: repository,
      connectivity: connectivity,
      signedInChanges: const Stream.empty(),
      retryDelays: const [
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
      ],
    )..start();

    connectivity.controller.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // First try leaves 2, the retry leaves 1, the next one sends the rest.
    expect(repository.syncCalls, 3);
    await sync.stop();
  });

  group('offline sync time', () {
    late FakeOfflineSyncMetricRepository metrics;
    late TestStopwatch stopwatch;
    late FakeLostReportRepository repository;
    late _StreamConnectivity connectivity;
    late StreamController<bool> signedIn;

    PendingReportSync build({List<Duration> retryDelays = const []}) =>
        PendingReportSync(
          repository: repository,
          connectivity: connectivity,
          signedInChanges: signedIn.stream,
          retryDelays: retryDelays,
          tracker: OfflineSyncTimeTracker(
            repository: metrics,
            createStopwatch: () => stopwatch,
          ),
        )..start();

    setUp(() {
      metrics = FakeOfflineSyncMetricRepository();
      stopwatch = TestStopwatch()..milliseconds = 2500;
      repository = FakeLostReportRepository()..queued = 3;
      connectivity = _StreamConnectivity();
      signedIn = StreamController<bool>();
    });

    test(
      'records one sample when the queue is sent after a recovery',
      () async {
        final sync = build();

        connectivity.controller.add(false);
        connectivity.controller.add(true);
        await pumpEventQueue();

        expect(metrics.records, hasLength(1));
        expect(metrics.records.single['reportCount'], 3);
        expect(metrics.records.single['durationMs'], 2500);
        expect(metrics.records.single['offlineDurationMs'], isNotNull);
        await sync.stop();
      },
    );

    test('includes the retries in the recovery', () async {
      repository.waitingAfterSync = [2];
      final sync = build(retryDelays: const [Duration(milliseconds: 1)]);

      connectivity.controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.syncCalls, 2);
      expect(metrics.records, hasLength(1));
      await sync.stop();
    });

    test('records nothing when reports are still waiting', () async {
      repository.waitingAfterSync = [2, 2];
      final sync = build(retryDelays: const [Duration(milliseconds: 1)]);

      connectivity.controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(metrics.records, isEmpty);
      await sync.stop();
    });

    test('records nothing when no report was waiting', () async {
      repository.queued = 0;
      final sync = build();

      connectivity.controller.add(true);
      await pumpEventQueue();

      expect(repository.syncCalls, 1);
      expect(metrics.records, isEmpty);
      await sync.stop();
    });

    test('signing in sends the queue but is not a recovery', () async {
      final sync = build();

      signedIn.add(true);
      await pumpEventQueue();

      expect(repository.syncCalls, 1);
      expect(metrics.records, isEmpty);
      await sync.stop();
    });
  });
}
