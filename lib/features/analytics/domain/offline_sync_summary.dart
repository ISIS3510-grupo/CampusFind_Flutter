// What the dashboard shows about the sync time after an offline period.
class OfflineSyncSummary {
  const OfflineSyncSummary({
    required this.sampleCount,
    required this.averageMs,
    required this.medianMs,
    required this.p95Ms,
    required this.msPerReport,
    required this.trendMsPerSample,
  });

  static const empty = OfflineSyncSummary(
    sampleCount: 0,
    averageMs: 0,
    medianMs: 0,
    p95Ms: 0,
    msPerReport: 0,
    trendMsPerSample: 0,
  );

  final int sampleCount;
  final double averageMs;
  final double medianMs;

  // 95% of the recoveries finished at or under this time.
  final double p95Ms;

  // Total sync time divided by the total number of reports sent.
  final double msPerReport;

  // Slope of the sync time over the recoveries in order: a positive value
  // means each recovery tends to take longer than the previous one.
  final double trendMsPerSample;

  bool get hasData => sampleCount > 0;
}
