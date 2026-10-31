import 'dart:isolate';

import 'package:campusfind_flutter/features/analytics/domain/offline_sync_sample.dart';
import 'package:campusfind_flutter/features/analytics/domain/offline_sync_summary.dart';

typedef OfflineSyncSummarizer = Future<OfflineSyncSummary> Function(
  List<OfflineSyncSample> samples,
);

// Calculates the sync time statistics in a separate isolate, so sorting and
// regression over a long history never block the UI thread.
class OfflineSyncStatsService {
  OfflineSyncStatsService({OfflineSyncSummarizer? summarizer})
    : _summarizer = summarizer ?? _summarizeInIsolate;

  final OfflineSyncSummarizer _summarizer;

  Future<OfflineSyncSummary> summarize(List<OfflineSyncSample> samples) =>
      _summarizer(samples);

  // The closure only captures the samples: plain data that can cross isolates.
  static Future<OfflineSyncSummary> _summarizeInIsolate(
    List<OfflineSyncSample> samples,
  ) => Isolate.run(() => computeOfflineSyncSummary(samples));
}

// Top-level and free of Flutter and Firebase, so an isolate can run it.
OfflineSyncSummary computeOfflineSyncSummary(List<OfflineSyncSample> samples) {
  if (samples.isEmpty) return OfflineSyncSummary.empty;

  final ordered = [...samples]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final durations = [
    for (final sample in ordered) sample.durationMs.toDouble(),
  ];
  final count = durations.length;
  final total = durations.fold<double>(0, (sum, value) => sum + value);
  final average = total / count;
  final totalReports = ordered.fold<int>(
    0,
    (sum, sample) => sum + sample.reportCount,
  );
  final sorted = [...durations]..sort();

  return OfflineSyncSummary(
    sampleCount: count,
    averageMs: average,
    medianMs: _median(sorted),
    p95Ms: _nearestRank(sorted, 95),
    msPerReport: totalReports == 0 ? 0 : total / totalReports,
    trendMsPerSample: _slope(durations, average),
  );
}

double _median(List<double> sorted) {
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

// Nearest-rank percentile with integer math, so 95% of 20 values is exactly
// the 19th and never drifts to the 20th by floating point error.
double _nearestRank(List<double> sorted, int percentile) {
  final rank = (percentile * sorted.length + 99) ~/ 100;
  return sorted[rank - 1];
}

// Least squares slope of the values against their position (ms per sample).
double _slope(List<double> values, double mean) {
  final count = values.length;
  if (count < 2) return 0;
  final xMean = (count - 1) / 2;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < count; i++) {
    numerator += (i - xMean) * (values[i] - mean);
    denominator += (i - xMean) * (i - xMean);
  }
  return numerator / denominator;
}
