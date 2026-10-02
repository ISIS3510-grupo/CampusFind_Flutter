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
}
