import 'package:campusfind_flutter/features/analytics/domain/offline_sync_sample.dart';

abstract interface class OfflineSyncMetricRepository {
  String? get currentUserId;

  Future<void> record({
    required String? uid,
    required int durationMs,
    required int reportCount,
    int? offlineDurationMs,
  });

  // Every valid recovery, oldest first.
  Future<List<OfflineSyncSample>> fetchSamples();
}
