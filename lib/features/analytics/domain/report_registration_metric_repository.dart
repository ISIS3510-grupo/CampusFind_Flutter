abstract interface class ReportRegistrationMetricRepository {
  String? get currentUserId;
  Future<void> record({
    required String? uid,
    required String reportType,
    required int durationMs,
  });
  static void validateReportType(String reportType) {
    if (reportType != 'lost' && reportType != 'found') {
      throw ArgumentError.value(
        reportType,
        'reportType',
        'Expected lost or found',
      );
    }
  }
}
