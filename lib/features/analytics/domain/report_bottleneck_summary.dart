class ReportBottleneckSummary {
  ReportBottleneckSummary({
    required Map<String, int> counts,
    required List<String> mostStuckStages,
    required List<String> missingTimestampReportIds,
  }) : counts = Map.unmodifiable({
         for (final stage in stages) stage: counts[stage] ?? 0,
       }),
       mostStuckStages = List.unmodifiable(mostStuckStages),
       missingTimestampReportIds = List.unmodifiable(missingTimestampReportIds);

  factory ReportBottleneckSummary.fromCounts(
    Map<String, int> counts, {
    List<String> missingTimestampReportIds = const [],
  }) {
    final stageCounts = {for (final stage in stages) stage: counts[stage] ?? 0};
    var highestCount = 0;
    for (final count in stageCounts.values) {
      if (count > highestCount) highestCount = count;
    }

    return ReportBottleneckSummary(
      counts: stageCounts,
      mostStuckStages: [
        if (highestCount > 0)
          for (final entry in stageCounts.entries)
            if (entry.value == highestCount) entry.key,
      ],
      missingTimestampReportIds: missingTimestampReportIds,
    );
  }

  static const stages = ['reported', 'found', 'ready_for_pickup', 'claimed'];

  final Map<String, int> counts;
  final List<String> mostStuckStages;
  final List<String> missingTimestampReportIds;

  bool get hasStuckReports => counts.values.any((count) => count > 0);
}
