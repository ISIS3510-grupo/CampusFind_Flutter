import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportRegistrationMetricRepository {
  const ReportRegistrationMetricRepository({this.firestore, this.firebaseAuth});

  final FirebaseFirestore? firestore;
  final FirebaseAuth? firebaseAuth;

  static void validateReportType(String reportType) {
    if (reportType != 'lost' && reportType != 'found') {
      throw ArgumentError.value(
        reportType,
        'reportType',
        'Expected lost or found',
      );
    }
  }

  Future<void> record({
    required String reportType,
    required int durationMs,
  }) async {
    validateReportType(reportType);
    if (durationMs < 0) {
      throw ArgumentError.value(
        durationMs,
        'durationMs',
        'Must be non-negative',
      );
    }
    final uid = (firebaseAuth ?? FirebaseAuth.instance).currentUser?.uid;
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
