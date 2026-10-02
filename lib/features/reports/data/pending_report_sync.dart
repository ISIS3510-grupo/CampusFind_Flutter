import 'dart:async';

import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';

// Sends the offline queue when the connection comes back or a student signs in.
class PendingReportSync {
  PendingReportSync({
    required this.repository,
    required this.connectivity,
    required this.signedInChanges,
    this.retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
  });

  final LostReportRepository repository;
  final ConnectivityService connectivity;
  final Stream<bool> signedInChanges;

  // The "connected" event often arrives before the network really works, so a
  // failed sync is retried a few times while reports are still waiting.
  final List<Duration> retryDelays;

  final List<StreamSubscription<bool>> _subscriptions = [];
  bool _syncing = false;

  void start() {
    _subscriptions
      ..add(connectivity.onlineChanges.where((online) => online).listen(_sync))
      ..add(signedInChanges.where((signedIn) => signedIn).listen(_sync));
  }

  Future<void> _sync(bool _) async {
    if (_syncing) return;
    _syncing = true;
    try {
      var waiting = await repository.syncPending();
      for (final delay in retryDelays) {
        if (waiting == 0 || !await connectivity.isOnline()) break;
        await Future<void>.delayed(delay);
        waiting = await repository.syncPending();
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
