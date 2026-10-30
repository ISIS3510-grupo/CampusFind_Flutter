import '../domain/report_registration_metric_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportRegistrationMetricRepositoryImpl
    implements ReportRegistrationMetricRepository {
  const ReportRegistrationMetricRepositoryImpl({
    this.firestore,
    this.firebaseAuth,
  });

  final FirebaseFirestore? firestore;
  final FirebaseAuth? firebaseAuth;

  @override
  String? get currentUserId =>
      (firebaseAuth ?? FirebaseAuth.instance).currentUser?.uid;

  @override
  Future<void> record({
    required String? uid,
    required String reportType,
    required int durationMs,
  }) async {
    ReportRegistrationMetricRepository.validateReportType(reportType);
    if (durationMs < 0) {
      throw ArgumentError.value(
        durationMs,
        'durationMs',
        'Must be non-negative',
      );
    }
    if (uid == null || uid.isEmpty) return;

    await (firestore ?? FirebaseFirestore.instance)
        .collection('performanceMetrics')
        .add({
          'metricType': 'report_registration',
          'uid': uid,
          'reportType': reportType,
          'platform': 'flutter',
          'durationMs': durationMs,
          'recordedAt': FieldValue.serverTimestamp(),
        });
  }
}
