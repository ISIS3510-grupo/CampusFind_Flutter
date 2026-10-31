import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:campusfind_flutter/features/analytics/domain/offline_sync_metric_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/offline_sync_sample.dart';

class OfflineSyncMetricRepositoryImpl implements OfflineSyncMetricRepository {
  const OfflineSyncMetricRepositoryImpl({this.firestore, this.firebaseAuth});

  static const metricType = 'offline_sync';

  final FirebaseFirestore? firestore;
  final FirebaseAuth? firebaseAuth;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  @override
  String? get currentUserId =>
      (firebaseAuth ?? FirebaseAuth.instance).currentUser?.uid;

  @override
  Future<void> record({
    required String? uid,
    required int durationMs,
    required int reportCount,
    int? offlineDurationMs,
  }) async {
    if (durationMs < 0) {
      throw ArgumentError.value(durationMs, 'durationMs', 'Must be >= 0');
    }
    if (reportCount < 1) {
      throw ArgumentError.value(reportCount, 'reportCount', 'Must be >= 1');
    }
    if (uid == null || uid.isEmpty) return;

    await _db.collection('performanceMetrics').add({
      'metricType': metricType,
      'uid': uid,
      'platform': 'flutter',
      'durationMs': durationMs,
      'reportCount': reportCount,
      'offlineDurationMs': ?offlineDurationMs,
      'recordedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<OfflineSyncSample>> fetchSamples() async {
    // From the server: the dashboard must not average a partial offline cache.
    final snapshot = await _db
        .collection('performanceMetrics')
        .where('metricType', isEqualTo: metricType)
        .get(const GetOptions(source: Source.server));

    final samples = <OfflineSyncSample>[
      for (final document in snapshot.docs) ?_parse(document.data()),
    ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return samples;
  }

  // Malformed documents are ignored, like in the registration time metric.
  static OfflineSyncSample? _parse(Map<String, dynamic> data) {
    final duration = data['durationMs'];
    final count = data['reportCount'];
    final recordedAt = data['recordedAt'];
    final offline = data['offlineDurationMs'];
    if (data['platform'] != 'flutter' ||
        duration is! num ||
        !duration.isFinite ||
        duration < 0 ||
        count is! num ||
        !count.isFinite ||
        count < 1 ||
        recordedAt is! Timestamp) {
      return null;
    }
    return OfflineSyncSample(
      durationMs: duration.round(),
      reportCount: count.round(),
      recordedAt: recordedAt.toDate(),
      offlineDurationMs: offline is num && offline.isFinite && offline >= 0
          ? offline.round()
          : null,
    );
  }
}
