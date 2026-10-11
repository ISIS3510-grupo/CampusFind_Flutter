import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/services/report_bottleneck_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ReportBottleneckService();
  final now = DateTime.utc(2026, 9, 30, 12);
  final old = now.subtract(const Duration(days: 10));
  const stages = ['reported', 'found', 'ready_for_pickup', 'claimed'];
  const zeroCounts = {
    'reported': 0,
    'found': 0,
    'ready_for_pickup': 0,
    'claimed': 0,
  };

  test('empty input includes all four zero counts and no highest stage', () {
    final summary = service.calculate([], now);
    expect(summary.counts, zeroCounts);
    expect(summary.mostStuckStages, isEmpty);
    expect(summary.missingTimestampReportIds, isEmpty);
    expect(summary.hasStuckReports, isFalse);
  });

  for (final stage in stages) {
    test(
      '$stage increments when its current stage is older than seven days',
      () {
        final summary = service.calculate([
          _report(status: stage, changedAt: old),
        ], now);
        expect(summary.counts, {...zeroCounts, stage: 1});
        expect(summary.mostStuckStages, [stage]);
        expect(summary.hasStuckReports, isTrue);
      },
    );
  }

  test('exactly seven elapsed days does not count', () {
    final summary = service.calculate([
      _report(changedAt: now.subtract(const Duration(days: 7))),
    ], now);
    expect(summary.counts, zeroCounts);
  });

  test('seven days plus one second counts', () {
    final summary = service.calculate([
      _report(changedAt: now.subtract(const Duration(days: 7, seconds: 1))),
    ], now);
    expect(summary.counts, {...zeroCounts, 'reported': 1});
  });

  test('six days and 23 hours does not count', () {
    final summary = service.calculate([
      _report(changedAt: now.subtract(const Duration(days: 6, hours: 23))),
    ], now);
    expect(summary.counts, zeroCounts);
  });

  test('closed reports are ignored even with an old timestamp', () {
    final summary = service.calculate([
      _report(status: 'closed', changedAt: old),
    ], now);
    expect(summary.counts, zeroCounts);
    expect(summary.missingTimestampReportIds, isEmpty);
  });

  test('unknown statuses are ignored with or without a timestamp', () {
    final summary = service.calculate([
      _report(status: 'unknown', changedAt: old),
      _report(id: 'missing', status: 'unknown'),
    ], now);
    expect(summary.counts, zeroCounts);
    expect(summary.missingTimestampReportIds, isEmpty);
  });

  test(
    'missing current-stage timestamps are reported for all relevant stages',
    () {
      final summary = service.calculate([
        for (final stage in stages) _report(id: stage, status: stage),
      ], now);
      expect(summary.counts, zeroCounts);
      expect(summary.missingTimestampReportIds, stages);
      expect(summary.hasStuckReports, isFalse);
    },
  );

  test('closed reports without timestamps are not reported as missing', () {
    final summary = service.calculate([_report(status: 'closed')], now);
    expect(summary.missingTimestampReportIds, isEmpty);
    expect(summary.counts, zeroCounts);
  });

  test('future timestamps do not count or appear as missing', () {
    final summary = service.calculate([
      _report(changedAt: now.add(const Duration(days: 10))),
    ], now);
    expect(summary.counts, zeroCounts);
    expect(summary.missingTimestampReportIds, isEmpty);
  });

  test('returns the single stage with the highest count', () {
    final summary = service.calculate([
      _report(id: 'r', changedAt: old),
      _report(id: 'f', status: 'found', changedAt: old),
      _report(id: 'p1', status: 'ready_for_pickup', changedAt: old),
      _report(id: 'p2', status: 'ready_for_pickup', changedAt: old),
      _report(id: 'c', status: 'claimed', changedAt: old),
    ], now);
    expect(summary.counts, {
      'reported': 1,
      'found': 1,
      'ready_for_pickup': 2,
      'claimed': 1,
    });
    expect(summary.mostStuckStages, ['ready_for_pickup']);
  });

  test('returns all tied highest stages in stage order', () {
    final summary = service.calculate([
      _report(id: 'f1', status: 'found', changedAt: old),
      _report(id: 'r1', changedAt: old),
      _report(id: 'f2', status: 'found', changedAt: old),
      _report(id: 'r2', changedAt: old),
      _report(id: 'p', status: 'ready_for_pickup', changedAt: old),
    ], now);
    expect(summary.counts, {
      ...zeroCounts,
      'reported': 2,
      'found': 2,
      'ready_for_pickup': 1,
    });
    expect(summary.mostStuckStages, ['reported', 'found']);
  });

  test('nonempty input with all zero counts has no winning stages', () {
    final summary = service.calculate([
      for (final stage in stages)
        _report(id: stage, status: stage, changedAt: now),
    ], now);
    expect(summary.counts, zeroCounts);
    expect(summary.mostStuckStages, isEmpty);
    expect(summary.hasStuckReports, isFalse);
  });

  test('multiple reports in a stage accumulate across different owners', () {
    final summary = service.calculate([
      for (var index = 0; index < 4; index++)
        _report(id: 'report-$index', ownerUid: 'owner-$index', changedAt: old),
    ], now);
    expect(summary.counts, {...zeroCounts, 'reported': 4});
  });

  test('does not mutate reports or reorder the supplied list', () {
    final first = _report(id: 'first', status: 'found', changedAt: old);
    final second = _report(id: 'second', changedAt: now);
    final reports = List<LostReport>.unmodifiable([first, second]);
    service.calculate(reports, now);
    expect(reports, orderedEquals([same(first), same(second)]));
    expect(first.status, 'found');
    expect(first.statusChangedAt, old);
    expect(second.status, 'reported');
    expect(second.statusChangedAt, now);
  });

  test('never falls back to reportedAt or lifecycle timestamps', () {
    // The fixture supplies old values for every other timestamp.
    final summary = service.calculate([
      _report(id: 'missing'),
      _report(id: 'recent', status: 'claimed', changedAt: now),
    ], now);
    expect(summary.counts, zeroCounts);
    expect(summary.missingTimestampReportIds, ['missing']);
  });

  test('each calculation is independent of previous results', () {
    final first = service.calculate([_report(changedAt: old)], now);
    final second = service.calculate([], now);
    expect(first.counts['reported'], 1);
    expect(second.counts, zeroCounts);
  });

  test('summary copies collections and exposes them as immutable', () {
    final counts = {'reported': 1};
    final winners = ['reported'];
    final missing = ['missing'];
    final summary = ReportBottleneckSummary(
      counts: counts,
      mostStuckStages: winners,
      missingTimestampReportIds: missing,
    );
    counts.clear();
    winners.clear();
    missing.clear();
    expect(summary.counts, {...zeroCounts, 'reported': 1});
    expect(summary.mostStuckStages, ['reported']);
    expect(summary.missingTimestampReportIds, ['missing']);
    expect(() => summary.counts['reported'] = 2, throwsUnsupportedError);
    expect(() => summary.mostStuckStages.clear(), throwsUnsupportedError);
    expect(
      () => summary.missingTimestampReportIds.clear(),
      throwsUnsupportedError,
    );
  });
}

LostReport _report({
  String id = 'report',
  String ownerUid = 'owner',
  String status = 'reported',
  DateTime? changedAt,
}) => LostReport(
  id: id,
  ownerUid: ownerUid,
  category: 'electronics',
  title: 'Calculator',
  description: 'Black calculator',
  status: status,
  locationName: 'ML',
  reportedAt: DateTime.utc(2026, 1, 1),
  statusChangedAt: changedAt,
  foundAt: DateTime.utc(2026, 1, 2),
  readyForPickupAt: DateTime.utc(2026, 1, 3),
  claimedAt: DateTime.utc(2026, 1, 4),
  closedAt: DateTime.utc(2026, 1, 5),
);
