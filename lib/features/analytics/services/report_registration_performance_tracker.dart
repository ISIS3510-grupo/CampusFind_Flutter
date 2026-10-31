import '../domain/report_registration_metric_repository.dart';

import 'dart:async';

import '../data/report_registration_metric_repository_impl.dart';

/// Call after validation, wrapping the complete backend registration operation,
/// including any required upload. The operation must await backend confirmation.
class ReportRegistrationPerformanceTracker {
  const ReportRegistrationPerformanceTracker({
    this.repository = const ReportRegistrationMetricRepositoryImpl(),
    this.createStopwatch = Stopwatch.new,
  });

  final ReportRegistrationMetricRepository repository;
  final Stopwatch Function() createStopwatch;

  Future<T> measure<T>({
    required String reportType,
    String? uid,
    bool Function(T result)? isSuccessful,
    required Future<T> Function() operation,
  }) async {
    ReportRegistrationMetricRepository.validateReportType(reportType);
    // Capture before starting uploads; an auth change must not reattribute work.
    String? submittingUid = uid;
    try {
      submittingUid ??= repository.currentUserId;
    } catch (_) {
      // Metrics are best effort, including when Firebase is not initialized.
    }
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
    if (isSuccessful == null || isSuccessful(result)) {
      unawaited(
        _recordSafely(submittingUid, reportType, stopwatch.elapsedMilliseconds),
      );
    }
    return result;
  }

  Future<void> _recordSafely(
    String? uid,
    String reportType,
    int durationMs,
  ) async {
    try {
      await repository.record(
        uid: uid,
        reportType: reportType,
        durationMs: durationMs,
      );
    } catch (_) {
      // Registration has already succeeded. Analytics cannot undo that success.
    }
  }
}
