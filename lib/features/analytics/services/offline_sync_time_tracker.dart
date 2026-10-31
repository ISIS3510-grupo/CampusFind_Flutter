import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:campusfind_flutter/features/analytics/data/offline_sync_metric_repository_impl.dart';
import 'package:campusfind_flutter/features/analytics/domain/offline_sync_metric_repository.dart';

// Measures how long the app takes to send the reports saved offline once the
// connection is back.
//
// The clock starts when the "connection is back" event arrives and stops when
// the last waiting report has reached the backend, so the retries made while
// the network is still unstable count as part of the time. Recoveries that do
// not finish (still offline, signed out) record nothing.
class OfflineSyncTimeTracker {
  OfflineSyncTimeTracker({
    OfflineSyncMetricRepository? repository,
    Stopwatch Function()? createStopwatch,
    DateTime Function()? now,
  }) : _repository = repository ?? const OfflineSyncMetricRepositoryImpl(),
       _createStopwatch = createStopwatch ?? Stopwatch.new,
       _now = now ?? DateTime.now;

  final OfflineSyncMetricRepository _repository;
  final Stopwatch Function() _createStopwatch;
  final DateTime Function() _now;

  DateTime? _offlineSince;

  // Call when the connection is lost. Only the first call of an offline
  // period counts.
  void markOffline() => _offlineSince ??= _now();

  // Call the moment the connection comes back, before anything else runs.
  OfflineSyncSession beginRecovery() {
    final since = _offlineSince;
    _offlineSince = null;
    final offlineMs = since == null
        ? null
        : _now().difference(since).inMilliseconds;
    return OfflineSyncSession._(
      this,
      _createStopwatch()..start(),
      offlineMs == null || offlineMs < 0 ? null : offlineMs,
    );
  }

  void _record(int durationMs, int reportCount, int? offlineDurationMs) {
    // Best effort: an offline analytics write must not delay the sync.
    unawaited(_recordSafely(durationMs, reportCount, offlineDurationMs));
  }

  Future<void> _recordSafely(
    int durationMs,
    int reportCount,
    int? offlineDurationMs,
  ) async {
    try {
      await _repository.record(
        uid: _repository.currentUserId,
        durationMs: durationMs,
        reportCount: reportCount,
        offlineDurationMs: offlineDurationMs,
      );
    } catch (error) {
      // The reports are already sent; analytics cannot undo that.
      debugPrint('Offline sync metric not saved: $error');
    }
  }
}

// One recovery in progress. Complete it once, when nothing is left waiting.
class OfflineSyncSession {
  OfflineSyncSession._(this._tracker, this._stopwatch, this._offlineDurationMs);

  final OfflineSyncTimeTracker _tracker;
  final Stopwatch _stopwatch;
  final int? _offlineDurationMs;
  bool _completed = false;

  void complete({required int reportCount}) {
    if (_completed || reportCount < 1) return;
    _completed = true;
    _stopwatch.stop();
    _tracker._record(
      _stopwatch.elapsedMilliseconds,
      reportCount,
      _offlineDurationMs,
    );
  }
}
