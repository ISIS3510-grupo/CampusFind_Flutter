import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_bottleneck_summary.dart';
import 'package:campusfind_flutter/features/analytics/services/report_bottleneck_aggregation_service.dart';
import 'package:campusfind_flutter/features/analytics/services/report_bottleneck_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 9, 30, 12);
  final old = now.subtract(const Duration(days: 10));
  const path = 'analytics/reportBottleneck';
  const zeroCounts = {
    'reported': 0,
    'found': 0,
    'ready_for_pickup': 0,
    'claimed': 0,
  };

  Map<String, dynamic> report({
    String status = 'reported',
    DateTime? changedAt,
  }) => {
    ...lostReportData(status: status, reportedAt: DateTime.utc(2026, 1, 1)),
    if (changedAt != null) 'statusChangedAt': Timestamp.fromDate(changedAt),
  };

  Future<ReportBottleneckSummary> refresh(FakeFirestore database) =>
      ReportBottleneckAggregationService(firestore: database).refresh(now: now);

  test(
    'reads all lostReports and writes only the aggregate document',
    () async {
      final database = FakeFirestore(
        documents: {
          'lostReports/a': report(changedAt: old),
          'lostReports/b': {
            ...report(changedAt: old),
            'ownerUid': 'another-owner',
          },
          'foundItems/unrelated': {},
        },
      );
      await refresh(database);
      expect(database.queries, [
        {'collection': 'lostReports'},
      ]);
      expect(database.documentReads, isEmpty);
      expect(database.documentWrites.single['path'], path);
      expect(database.documents[path]!['reported'], 2);
    },
  );

  test('reported older than seven days increments reported', () async {
    final summary = await refresh(
      FakeFirestore(documents: {'lostReports/a': report(changedAt: old)}),
    );
    expect(summary.counts, {...zeroCounts, 'reported': 1});
  });

  test('exactly seven days does not count', () async {
    final summary = await refresh(
      FakeFirestore(
        documents: {
          'lostReports/a': report(
            changedAt: now.subtract(const Duration(days: 7)),
          ),
        },
      ),
    );
    expect(summary.counts, zeroCounts);
  });

  test('seven days plus one second counts', () async {
    final summary = await refresh(
      FakeFirestore(
        documents: {
          'lostReports/a': report(
            changedAt: now.subtract(const Duration(days: 7, seconds: 1)),
          ),
        },
      ),
    );
    expect(summary.counts, {...zeroCounts, 'reported': 1});
  });

  test('multiple stages have independent counts', () async {
    final summary = await refresh(
      FakeFirestore(
        documents: {
          'lostReports/a': report(changedAt: old),
          'lostReports/b': report(status: 'found', changedAt: old),
          'lostReports/c': report(status: 'ready_for_pickup', changedAt: old),
          'lostReports/d': report(status: 'claimed', changedAt: old),
          'lostReports/e': report(status: 'found', changedAt: old),
        },
      ),
    );
    expect(summary.counts, {
      'reported': 1,
      'found': 2,
      'ready_for_pickup': 1,
      'claimed': 1,
    });
    expect(summary.mostStuckStages, ['found']);
  });

  for (final status in ['closed', 'unknown']) {
    test('$status reports are ignored', () async {
      final summary = await refresh(
        FakeFirestore(
          documents: {'lostReports/a': report(status: status, changedAt: old)},
        ),
      );
      expect(summary.counts, zeroCounts);
      expect(summary.mostStuckStages, isEmpty);
    });
  }

  test(
    'missing statusChangedAt does not count despite an old reportedAt',
    () async {
      final summary = await refresh(
        FakeFirestore(documents: {'lostReports/missing': report()}),
      );
      expect(summary.counts, zeroCounts);
    },
  );

  test('returns missing timestamp IDs for internal diagnostics', () async {
    final summary = await refresh(
      FakeFirestore(documents: {'lostReports/missing': report()}),
    );
    expect(summary.missingTimestampReportIds, ['missing']);
  });

  test('does not persist missing timestamp IDs', () async {
    final database = FakeFirestore(
      documents: {'lostReports/missing': report()},
    );
    await refresh(database);
    expect(
      database.documents[path]!.containsKey('missingTimestampReportIds'),
      isFalse,
    );
    expect(database.documents[path]!.values, isNot(contains('missing')));
  });

  test('persists exactly four counts and updatedAt', () async {
    final database = FakeFirestore(
      documents: {'lostReports/a': report(changedAt: old)},
    );
    await refresh(database);
    expect(
      database.documents[path]!.keys,
      unorderedEquals([
        'reported',
        'found',
        'ready_for_pickup',
        'claimed',
        'updatedAt',
      ]),
    );
    expect(database.documents[path]!.containsKey('mostStuckStages'), isFalse);
  });

  test('does not persist any source report or private fields', () async {
    final database = FakeFirestore(
      documents: {
        'lostReports/private-id': {
          ...report(changedAt: old),
          'ownerUid': 'private-owner',
          'email': 'private@example.com',
          'title': 'Private title',
          'description': 'Private description',
          'locationName': 'Private location',
        },
      },
    );
    await refresh(database);
    expect(database.documents[path], {
      ...zeroCounts,
      'reported': 1,
      'updatedAt': Timestamp.fromDate(now),
    });
    expect(database.documentWrites.single['data'], database.documents[path]);
  });

  test('all-zero results are still written', () async {
    final database = FakeFirestore(
      documents: {'lostReports/recent': report(changedAt: now)},
    );
    final summary = await refresh(database);
    expect(summary.hasStuckReports, isFalse);
    expect(database.documentWrites, hasLength(1));
    expect(database.documents[path], {
      ...zeroCounts,
      'updatedAt': Timestamp.fromDate(now),
    });
  });

  test('updatedAt equals the supplied fixed clock', () async {
    final database = FakeFirestore();
    await refresh(database);
    expect(
      (database.documents[path]!['updatedAt'] as Timestamp).toDate().toUtc(),
      now,
    );
  });

  test('returned summary matches all persisted counts', () async {
    final database = FakeFirestore(
      documents: {
        'lostReports/a': report(status: 'claimed', changedAt: old),
        'lostReports/b': report(status: 'found', changedAt: old),
      },
    );
    final summary = await refresh(database);
    final persisted = Map<String, dynamic>.of(database.documents[path]!)
      ..remove('updatedAt');
    expect(persisted, summary.counts);
    expect(summary.mostStuckStages, ['found', 'claimed']);
  });

  test('Firestore read errors propagate unchanged', () async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final database = FakeFirestore(errors: {'lostReports': error});
    await expectLater(refresh(database), throwsA(same(error)));
  });

  test(
    'failed reads never attempt a write or replace existing analytics',
    () async {
      final previous = {...zeroCounts, 'reported': 9};
      final database = FakeFirestore(
        documents: {path: previous},
        errors: {'lostReports': StateError('Offline')},
      );
      await expectLater(refresh(database), throwsStateError);
      expect(database.documentWrites, isEmpty);
      expect(database.documents[path], previous);
    },
  );

  test(
    'Firestore write errors propagate without returning a summary',
    () async {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final database = FakeFirestore(writeErrors: {path: error});
      await expectLater(refresh(database), throwsA(same(error)));
      expect(database.documentWrites.single['path'], path);
      expect(database.documents.containsKey(path), isFalse);
    },
  );

  test('source report data remains unchanged', () async {
    final source = report(status: 'found', changedAt: old);
    final original = Map<String, dynamic>.of(source);
    final database = FakeFirestore(documents: {'lostReports/a': source});
    await refresh(database);
    expect(source, original);
    expect(database.documents['lostReports/a'], original);
  });

  test(
    'delegates parsed reports and the supplied clock to the injected service',
    () async {
      final calculation = _Calculation();
      final database = FakeFirestore(
        documents: {'lostReports/a': report(changedAt: old)},
      );
      final summary = await ReportBottleneckAggregationService(
        firestore: database,
        bottleneckService: calculation,
      ).refresh(now: now);
      expect(calculation.calls, 1);
      expect(calculation.now, now);
      expect(calculation.reports.single.id, 'a');
      expect(calculation.reports.single.statusChangedAt?.toUtc(), old);
      expect(summary, same(calculation.result));
      expect(database.documents[path], {
        ...calculation.result.counts,
        'updatedAt': Timestamp.fromDate(now),
      });
    },
  );

  test(
    'replacement writes remove stale fields and reset counts for empty input',
    () async {
      final database = FakeFirestore(
        documents: {
          path: {
            'reported': 99,
            'ownerUid': 'stale-private-field',
            'missingTimestampReportIds': ['old-id'],
          },
        },
      );
      await refresh(database);
      expect(database.documents[path], {
        ...zeroCounts,
        'updatedAt': Timestamp.fromDate(now),
      });
    },
  );

  test('invalid required report fields propagate a parsing failure without writing', () async {
    final database = FakeFirestore(documents: {'lostReports/invalid': {}});
    await expectLater(refresh(database), throwsA(isA<TypeError>()));
    expect(database.documentWrites, isEmpty);
  });
}

class _Calculation extends ReportBottleneckService {
  final result = ReportBottleneckSummary.fromCounts({'claimed': 12});
  List<LostReport> reports = [];
  DateTime? now;
  int calls = 0;

  @override
  ReportBottleneckSummary calculate(List<LostReport> reports, DateTime now) {
    calls++;
    this.reports = reports;
    this.now = now;
    return result;
  }
}
