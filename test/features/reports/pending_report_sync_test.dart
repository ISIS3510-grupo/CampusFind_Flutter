import 'dart:async';

import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/reports/data/pending_report_sync.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
