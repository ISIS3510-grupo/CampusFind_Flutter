import 'package:campusfind_flutter/features/analytics/data/report_bottleneck_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';

void main() {
  const path = 'analytics/reportBottleneck';
  const zeroCounts = {
    'reported': 0,
    'found': 0,
    'ready_for_pickup': 0,
    'claimed': 0,
  };

  ReportBottleneckRepository repository(Map<String, dynamic> data) =>
      ReportBottleneckRepository(
        firestore: FakeFirestore(documents: {path: data}),
      );

  test(
    'reads only the aggregate document and reconstructs its summary',
    () async {
      final database = FakeFirestore(
        documents: {
          path: {
            'reported': 8,
            'found': 3,
            'ready_for_pickup': 5,
            'claimed': 1,
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 30)),
          },
        },
      );
      final summary = await ReportBottleneckRepository(firestore: database)
          .getSummary();
      expect(summary.counts, {
        'reported': 8,
        'found': 3,
        'ready_for_pickup': 5,
        'claimed': 1,
      });
      expect(summary.mostStuckStages, ['reported']);
      expect(summary.hasStuckReports, isTrue);
      expect(summary.missingTimestampReportIds, isEmpty);
      expect(database.documentReads, [path]);
      expect(database.queries, isEmpty);
    },
  );

  test('preserves all tied highest stages in stage order', () async {
    final summary = await repository({
      'reported': 5,
      'found': 5,
      'ready_for_pickup': 2,
      'claimed': 1,
    }).getSummary();
    expect(summary.mostStuckStages, ['reported', 'found']);
  });

  test('all zeros have no highest stage or stuck reports', () async {
    final summary = await repository(zeroCounts).getSummary();
    expect(summary.counts, zeroCounts);
    expect(summary.mostStuckStages, isEmpty);
    expect(summary.hasStuckReports, isFalse);
  });

  test('missing fields become zero without affecting valid fields', () async {
    final summary = await repository({'found': 3}).getSummary();
    expect(summary.counts, {...zeroCounts, 'found': 3});
    expect(summary.mostStuckStages, ['found']);
  });

  test('an existing empty document yields zero counts', () async {
    final summary = await repository({}).getSummary();
    expect(summary.counts, zeroCounts);
    expect(summary.mostStuckStages, isEmpty);
  });

  test('invalid count types become zero for each stage', () async {
    for (final stage in zeroCounts.keys) {
      for (final value in <Object?>[
        null,
        '8',
        true,
        1.5,
        5.0,
        double.nan,
        double.infinity,
        [],
        {},
      ]) {
        final summary = await repository({
          'reported': 1,
          'found': 2,
          'ready_for_pickup': 3,
          'claimed': 4,
          stage: value,
        }).getSummary();
        expect(summary.counts, {
          'reported': 1,
          'found': 2,
          'ready_for_pickup': 3,
          'claimed': 4,
          stage: 0,
        });
      }
    }
  });

  test('negative counts become zero for each stage', () async {
    final summary = await repository({
      for (final stage in zeroCounts.keys) stage: -1,
    }).getSummary();
    expect(summary.counts, zeroCounts);
    expect(summary.hasStuckReports, isFalse);
  });

  test(
    'ignores unrelated fields and never exposes report identifiers',
    () async {
      final summary = await repository({
        'claimed': 2,
        'closed': 100,
        'ownerUid': 'ignored-owner',
        'email': 'ignored@example.com',
        'missingTimestampReportIds': ['ignored-report'],
        'mostStuckStages': ['closed'],
      }).getSummary();
      expect(summary.counts, {...zeroCounts, 'claimed': 2});
      expect(summary.mostStuckStages, ['claimed']);
      expect(summary.missingTimestampReportIds, isEmpty);
    },
  );

  test('a missing document throws a clear failure', () async {
    final repo = ReportBottleneckRepository(firestore: FakeFirestore());
    await expectLater(
      repo.getSummary(),
      throwsA(
        isA<ReportBottleneckNotGeneratedException>().having(
          (error) => error.message,
          'message',
          contains(path),
        ),
      ),
    );
  });

  test('Firestore read failures propagate unchanged', () async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final repo = ReportBottleneckRepository(
      firestore: FakeFirestore(errors: {path: error}),
    );
    await expectLater(repo.getSummary(), throwsA(same(error)));
  });
}
