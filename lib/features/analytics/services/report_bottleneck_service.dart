import '../../../core/models/lost_report.dart';
import '../domain/report_bottleneck_summary.dart';

class ReportBottleneckService {
  const ReportBottleneckService();

  ReportBottleneckSummary calculate(List<LostReport> reports, DateTime now) {
    final counts = {
      for (final stage in ReportBottleneckSummary.stages) stage: 0,
    };
    final missingTimestampReportIds = <String>[];

    for (final report in reports) {
      if (!counts.containsKey(report.status)) continue;

      final statusChangedAt = report.statusChangedAt;
      if (statusChangedAt == null) {
        missingTimestampReportIds.add(report.id);
        continue;
      }

      if (now.difference(statusChangedAt) > const Duration(days: 7)) {
        counts[report.status] = counts[report.status]! + 1;
      }
    }

    return ReportBottleneckSummary.fromCounts(
      counts,
      missingTimestampReportIds: missingTimestampReportIds,
    );
  }
}
