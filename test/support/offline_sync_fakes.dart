import 'dart:async';

import 'package:campusfind_flutter/features/analytics/domain/offline_sync_metric_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/offline_sync_sample.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineSyncSample syncSample(
  int index,
  int durationMs, {
  int reportCount = 1,
  int? offlineDurationMs,
}) => OfflineSyncSample(
  durationMs: durationMs,
  reportCount: reportCount,
  offlineDurationMs: offlineDurationMs,
  recordedAt: DateTime(2026, 1, 1).add(Duration(hours: index)),
);

class FakeOfflineSyncMetricRepository implements OfflineSyncMetricRepository {
  @override
  String? currentUserId = 'student-1';

  final records = <Map<String, Object?>>[];
  List<OfflineSyncSample> samples = [];
  Object? recordError;
  Object? fetchError;
  Completer<List<OfflineSyncSample>>? pendingFetch;
  int fetchCalls = 0;

  @override
  Future<void> record({
    required String? uid,
    required int durationMs,
    required int reportCount,
    int? offlineDurationMs,
  }) async {
    records.add({
      'uid': uid,
      'durationMs': durationMs,
      'reportCount': reportCount,
      'offlineDurationMs': offlineDurationMs,
    });
    if (recordError != null) throw recordError!;
  }

  @override
  Future<List<OfflineSyncSample>> fetchSamples() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return pendingFetch == null ? samples : await pendingFetch!.future;
  }
}

class TestStopwatch extends Fake implements Stopwatch {
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
