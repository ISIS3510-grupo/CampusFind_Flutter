import 'package:campusfind_flutter/features/analytics/services/offline_sync_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/offline_sync_fakes.dart';

void main() {
  group('computeOfflineSyncSummary', () {
    test('returns an empty summary without samples', () {
      final summary = computeOfflineSyncSummary([]);

      expect(summary.hasData, isFalse);
      expect(summary.sampleCount, 0);
    });

    test('average, median, time per report and rising trend', () {
      final summary = computeOfflineSyncSummary([
        syncSample(0, 1000, reportCount: 2),
        syncSample(1, 2000, reportCount: 2),
        syncSample(2, 3000, reportCount: 2),
      ]);

      expect(summary.sampleCount, 3);
      expect(summary.averageMs, 2000);
      expect(summary.medianMs, 2000);
      expect(summary.msPerReport, 1000);
      expect(summary.trendMsPerSample, closeTo(1000, 0.001));
    });

    test('median of an even number of samples is the middle pair mean', () {
      final summary = computeOfflineSyncSummary([
        syncSample(0, 1000),
        syncSample(1, 2000),
        syncSample(2, 4000),
        syncSample(3, 10000),
      ]);

      expect(summary.medianMs, 3000);
    });

    test('p95 uses the nearest rank', () {
      final twenty = [for (var i = 1; i <= 20; i++) syncSample(i, i * 100)];

      // 95% of 20 samples is the 19th value, never the maximum.
      expect(computeOfflineSyncSummary(twenty).p95Ms, 1900);
      expect(computeOfflineSyncSummary([syncSample(0, 700)]).p95Ms, 700);
    });

    test('trend is negative when each recovery is faster', () {
      final summary = computeOfflineSyncSummary([
        syncSample(0, 3000),
        syncSample(1, 2000),
        syncSample(2, 1000),
      ]);

      expect(summary.trendMsPerSample, closeTo(-1000, 0.001));
    });

    test('trend is 0 with a single sample', () {
      expect(
        computeOfflineSyncSummary([syncSample(0, 500)]).trendMsPerSample,
        0,
      );
    });

    test('orders by recording time, not by list order', () {
      final summary = computeOfflineSyncSummary([
        syncSample(2, 3000),
        syncSample(0, 1000),
        syncSample(1, 2000),
      ]);

      expect(summary.trendMsPerSample, closeTo(1000, 0.001));
    });
  });

  group('OfflineSyncStatsService', () {
    test('runs the calculation in an isolate with the same result', () async {
      final samples = [
        syncSample(0, 1000, reportCount: 4),
        syncSample(1, 3000, reportCount: 4),
      ];

      final summary = await OfflineSyncStatsService().summarize(samples);

      expect(summary.averageMs, 2000);
      expect(summary.msPerReport, 500);
    });

    test('accepts another summarizer', () async {
      final service = OfflineSyncStatsService(
        summarizer: (samples) async => computeOfflineSyncSummary(samples),
      );

      expect((await service.summarize([syncSample(0, 10)])).sampleCount, 1);
    });
  });
}
