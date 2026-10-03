import 'dart:async';

import 'package:campusfind_flutter/features/analytics/data/report_registration_metric_repository.dart';
import 'package:campusfind_flutter/features/analytics/data/report_registration_time_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_registration_time_summary.dart';
import 'package:campusfind_flutter/features/analytics/services/report_registration_time_aggregation_service.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/report_registration_time_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRegistrationTimeSummary registrationSummary({
  int lostCount = 2,
  double lostMs = 842,
  int foundCount = 1,
  double foundMs = 1240,
}) => ReportRegistrationTimeSummary(
  sampleCount: lostCount + foundCount,
  averageMs: lostCount + foundCount == 0
      ? null
      : (lostCount * lostMs + foundCount * foundMs) / (lostCount + foundCount),
  lostCount: lostCount,
  lostAverageMs: lostCount == 0 ? null : lostMs,
  foundCount: foundCount,
  foundAverageMs: foundCount == 0 ? null : foundMs,
);

class FakeRegistrationMetricRepository
    extends ReportRegistrationMetricRepository {
  final records = <Map<String, Object>>[];
  Object? error;
  Completer<void>? pending;

  @override
  Future<void> record({
    required String reportType,
    required int durationMs,
  }) async {
    records.add({'reportType': reportType, 'durationMs': durationMs});
    if (error != null) throw error!;
    await pending?.future;
  }
}

class FakeRegistrationTimeRepository extends ReportRegistrationTimeRepository {
  ReportRegistrationTimeSummary summary = registrationSummary();
  Object? error;
  Completer<ReportRegistrationTimeSummary>? pending;
  int calls = 0;

  @override
  Future<ReportRegistrationTimeSummary> getSummary() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? summary : await pending!.future;
  }
}

class FakeRegistrationTimeAggregationService
    extends ReportRegistrationTimeAggregationService {
  ReportRegistrationTimeSummary summary = registrationSummary(lostCount: 4);
  Object? error;
  Completer<ReportRegistrationTimeSummary>? pending;
  DateTime? receivedNow;
  int calls = 0;

  @override
  Future<ReportRegistrationTimeSummary> refresh({required DateTime now}) async {
    calls++;
    receivedNow = now;
    if (error != null) throw error!;
    return pending == null ? summary : await pending!.future;
  }
}

ReportRegistrationTimeViewModel testRegistrationTimeViewModel() {
  final model = ReportRegistrationTimeViewModel(
    repository: FakeRegistrationTimeRepository(),
    aggregationService: FakeRegistrationTimeAggregationService(),
  );
  addTearDown(model.dispose);
  return model;
}
