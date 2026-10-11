import 'dart:async';

import '../data/report_registration_metric_repository.dart';

/// Call after validation, wrapping the complete backend registration operation,
/// including any required upload. The operation must await backend confirmation.
class ReportRegistrationPerformanceTracker {
  const ReportRegistrationPerformanceTracker({
    this.repository = const ReportRegistrationMetricRepository(),
    this.createStopwatch = Stopwatch.new,
  });

  final ReportRegistrationMetricRepository repository;
  final Stopwatch Function() createStopwatch;

  Future<T> measure<T>({
    required String reportType,
    required Future<T> Function() operation,
  }) async {
    ReportRegistrationMetricRepository.validateReportType(reportType);
    final stopwatch = createStopwatch()..start();
    final T result;
    try {
      result = await operation();
    } catch (_) {
      stopwatch.stop();
      rethrow;
    }
    stopwatch.stop();
    // Best effort: an offline analytics write must not delay success navigation.
    unawaited(_recordSafely(reportType, stopwatch.elapsedMilliseconds));
    return result;
  }

  Future<void> _recordSafely(String reportType, int durationMs) async {
    try {
      await repository.record(reportType: reportType, durationMs: durationMs);
    } catch (_) {
      // Registration has already succeeded. Analytics cannot undo that success.
    }
  }
}
