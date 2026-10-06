import 'dart:async';

import 'package:campusfind_flutter/features/analytics/data/report_bottleneck_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/services/report_bottleneck_aggregation_service.dart';

class FakeReportBottleneckRepository extends ReportBottleneckRepository {
  ReportBottleneckSummary summary = ReportBottleneckSummary.fromCounts({
    'reported': 8,
  });
  Object? error;
  Completer<ReportBottleneckSummary>? pending;
  int calls = 0;

  @override
  Future<ReportBottleneckSummary> getSummary() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? summary : await pending!.future;
  }
}

class FakeReportBottleneckAggregationService
    extends ReportBottleneckAggregationService {
  ReportBottleneckSummary summary = ReportBottleneckSummary.fromCounts({
    'claimed': 3,
  });
  Object? error;
  Completer<ReportBottleneckSummary>? pending;
  DateTime? receivedNow;
  int calls = 0;

  @override
  Future<ReportBottleneckSummary> refresh({required DateTime now}) async {
    calls++;
    receivedNow = now;
    if (error != null) throw error!;
    return pending == null ? summary : await pending!.future;
  }
}
