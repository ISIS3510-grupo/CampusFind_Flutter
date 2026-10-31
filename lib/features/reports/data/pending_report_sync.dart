import 'dart:async';

import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/analytics/services/offline_sync_time_tracker.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';

// Sends the offline queue when the connection comes back or a student signs in.
class PendingReportSync {
  PendingReportSync({
    required this.repository,
    required this.connectivity,
    required this.signedInChanges,
    this.tracker,
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

  // Measures how long each recovery takes. Optional: without it the queue is
  // sent exactly the same, just without recording the time.
  final OfflineSyncTimeTracker? tracker;

  // The "connected" event often arrives before the network really works, so a
  // failed sync is retried a few times while reports are still waiting.
  final List<Duration> retryDelays;

  final List<StreamSubscription<bool>> _subscriptions = [];
  bool _syncing = false;

  void start() {
    _subscriptions
      ..add(connectivity.onlineChanges.listen(_onOnlineChanged))
      ..add(
        signedInChanges
            .where((signedIn) => signedIn)
            .listen((_) => unawaited(_sync())),
      );
  }

  void _onOnlineChanged(bool online) {
    if (!online) {
      tracker?.markOffline();
      return;
    }
    unawaited(_sync(connectionRecovered: true));
  }

  // Only a recovery of the connection is timed; signing in is not one.
  Future<void> _sync({bool connectionRecovered = false}) async {
    if (_syncing) return;
    _syncing = true;
    // The clock starts first, so counting the waiting reports is timed too.
    final session = connectionRecovered ? tracker?.beginRecovery() : null;
    try {
      final queued = session == null ? 0 : await repository.pendingCount();
      var waiting = await repository.syncPending();
      for (final delay in retryDelays) {
        if (waiting == 0 || !await connectivity.isOnline()) break;
        await Future<void>.delayed(delay);
        waiting = await repository.syncPending();
      }
      if (waiting == 0) session?.complete(reportCount: queued);
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
