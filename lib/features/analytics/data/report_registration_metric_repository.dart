import 'package:cloud_firestore/cloud_firestore.dart';

class ReportRegistrationMetricRepository {
  const ReportRegistrationMetricRepository({this.firestore});

  final FirebaseFirestore? firestore;

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
    await (firestore ?? FirebaseFirestore.instance)
        .collection('performanceMetrics')
        .add({
          'metricType': 'report_registration',
          'reportType': reportType,
          'platform': 'flutter',
          'durationMs': durationMs,
          'recordedAt': FieldValue.serverTimestamp(),
        });
  }
}
