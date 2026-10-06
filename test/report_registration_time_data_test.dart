import 'package:campusfind_flutter/features/analytics/data/report_registration_metric_repository.dart';
import 'package:campusfind_flutter/features/analytics/data/report_registration_time_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/report_registration_time_summary.dart';
import 'package:campusfind_flutter/features/analytics/services/report_registration_time_aggregation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';
import 'support/registration_time_fakes.dart';

Map<String, dynamic> sample(
  String type,
  Object? duration, {
  String platform = 'flutter',
  String metric = 'report_registration',
}) => {
  'metricType': metric,
  'reportType': type,
  'platform': platform,
  'durationMs': duration,
};

void main() {
  final now = DateTime.utc(2026, 9, 30);
  const aggregatePath = 'analytics/reportRegistrationTime';

  test('metrics use unique auto IDs, server timestamp and exactly five anonymous fields', () async {
    final database = FakeFirestore();
    final repository = ReportRegistrationMetricRepository(firestore: database);
    for (final type in ['lost', 'found']) {
      await repository.record(
        reportType: type,
        durationMs: type == 'lost' ? 842 : 0,
      );
    }
    expect(database.documentWrites.map((w) => w['path']), [
      'performanceMetrics/auto-1',
      'performanceMetrics/auto-2',
    ]);
    for (var i = 0; i < 2; i++) {
      expect(database.documentWrites[i]['data'], {
        'metricType': 'report_registration',
        'reportType': i == 0 ? 'lost' : 'found',
        'platform': 'flutter',
        'durationMs': i == 0 ? 842 : 0,
        'recordedAt': FieldValue.serverTimestamp(),
      });
    }
  });

  test(
    'invalid type and negative duration rejected before any write',
    () async {
      final database = FakeFirestore();
      final repository = ReportRegistrationMetricRepository(
        firestore: database,
      );
      await expectLater(
        repository.record(reportType: 'other', durationMs: 1),
        throwsArgumentError,
      );
      await expectLater(
        repository.record(reportType: 'lost', durationMs: -1),
        throwsArgumentError,
      );
      expect(database.documentWrites, isEmpty);
    },
  );

  test('metric repository exposes write errors to the tracker', () async {
    final error = StateError('write failed');
    final database = FakeFirestore(
      writeErrors: {'performanceMetrics/auto-1': error},
    );
    await expectLater(
      ReportRegistrationMetricRepository(firestore: database)
          .record(reportType: 'found', durationMs: 1),
      throwsA(same(error)),
    );
    expect(database.documents, isEmpty);
  });

  test('aggregation computes weighted overall and type averages and replaces only aggregate', () async {
    final database = FakeFirestore(
      documents: {
        'performanceMetrics/1': {
          ...sample('lost', 800),
          'privateExtra': 'never copy',
        },
        'performanceMetrics/2': sample('lost', 1000),
        'performanceMetrics/3': sample('found', 1500),
        aggregatePath: {'obsolete': true},
      },
    );
    final summary = await ReportRegistrationTimeAggregationService(
      firestore: database,
    ).refresh(now: now);
    expect(summary.toMap(), {
      'sampleCount': 3,
      'averageMs': 1100.0,
      'lostCount': 2,
      'lostAverageMs': 900.0,
      'foundCount': 1,
      'foundAverageMs': 1500.0,
    });
    expect(database.queries, [
      {
        'collection': 'performanceMetrics',
        'field': 'metricType',
        'isEqualTo': 'report_registration',
      },
    ]);
    expect(database.queryReadOptions.single!.source, Source.server);
    expect(database.documentWrites, [
      {
        'path': aggregatePath,
        'data': {...summary.toMap(), 'updatedAt': Timestamp.fromDate(now)},
      },
    ]);
    expect(
      database.documents['performanceMetrics/1']!['privateExtra'],
      'never copy',
    );
  });

  test(
    'unrelated platforms, types and malformed durations are ignored safely',
    () async {
      final invalid = [
        null,
        '100',
        true,
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        <int>[],
      ];
      final database = FakeFirestore(
        documents: {
          'performanceMetrics/valid': sample('found', 842.5),
          'performanceMetrics/kotlin': sample('lost', 900, platform: 'kotlin'),
          'performanceMetrics/other': sample('lost', 900, metric: 'other'),
          'performanceMetrics/unknown': sample('other', 900),
          'performanceMetrics/missing': {'metricType': 'report_registration'},
          for (var i = 0; i < invalid.length; i++)
            'performanceMetrics/bad$i': sample('lost', invalid[i]),
        },
      );
      final summary = await ReportRegistrationTimeAggregationService(
        firestore: database,
      ).refresh(now: now);
      expect(
        summary.toMap(),
        registrationSummary(lostCount: 0, foundMs: 842.5).toMap(),
      );
    },
  );

  test('empty data persists zero counts and null averages', () async {
    final database = FakeFirestore();
    final summary = await ReportRegistrationTimeAggregationService(
      firestore: database,
    ).refresh(now: now);
    expect(summary.hasData, isFalse);
    expect(
      summary.toMap(),
      registrationSummary(lostCount: 0, foundCount: 0).toMap(),
    );
    expect(database.documents[aggregatePath], {
      ...summary.toMap(),
      'updatedAt': Timestamp.fromDate(now),
    });
  });

  for (final type in ['lost', 'found']) {
    test(
      'single $type zero-duration sample is real data; other average stays null',
      () async {
        final database = FakeFirestore(
          documents: {'performanceMetrics/1': sample(type, 0)},
        );
        final summary = await ReportRegistrationTimeAggregationService(
          firestore: database,
        ).refresh(now: now);
        expect(summary.hasData, isTrue);
        expect(summary.averageMs, 0);
        expect(summary.lostCount, type == 'lost' ? 1 : 0);
        expect(summary.foundCount, type == 'found' ? 1 : 0);
        expect(summary.lostAverageMs, type == 'lost' ? 0 : null);
        expect(summary.foundAverageMs, type == 'found' ? 0 : null);
      },
    );
  }

  test('finite large durations do not overflow the average', () async {
    final database = FakeFirestore(
      documents: {
        'performanceMetrics/1': sample('lost', 1e308),
        'performanceMetrics/2': sample('lost', 1e308),
      },
    );
    expect(
      (await ReportRegistrationTimeAggregationService(firestore: database)
              .refresh(now: now))
          .averageMs,
      1e308,
    );
  });

  test(
    'refresh recalculates rather than accumulates and clears removed data',
    () async {
      final database = FakeFirestore(
        documents: {'performanceMetrics/1': sample('lost', 500)},
      );
      final service = ReportRegistrationTimeAggregationService(
        firestore: database,
      );
      await service.refresh(now: now);
      expect((await service.refresh(now: now)).sampleCount, 1);
      database.documents.remove('performanceMetrics/1');
      expect((await service.refresh(now: now)).hasData, isFalse);
    },
  );

  for (final readFailure in [true, false]) {
    test(
      '${readFailure ? 'query' : 'write'} failure preserves prior aggregate',
      () async {
        final error = StateError('unavailable');
        final old = registrationSummary().toMap();
        final database = FakeFirestore(
          documents: {aggregatePath: old},
          errors: readFailure ? {'performanceMetrics': error} : {},
          writeErrors: readFailure ? {} : {aggregatePath: error},
        );
        await expectLater(
          ReportRegistrationTimeAggregationService(firestore: database)
              .refresh(now: now),
          throwsA(same(error)),
        );
        expect(database.documents[aggregatePath], old);
        if (readFailure) expect(database.documentWrites, isEmpty);
      },
    );
  }

  test(
    'repository reads only aggregate and handles integer and nullable averages',
    () async {
      final database = FakeFirestore(
        documents: {
          aggregatePath: {
            'sampleCount': 1,
            'averageMs': 842,
            'lostCount': 1,
            'lostAverageMs': 842,
            'foundCount': 0,
            'foundAverageMs': null,
          },
        },
      );
      final summary = await ReportRegistrationTimeRepository(
        firestore: database,
      ).getSummary();
      expect(summary.averageMs, 842.0);
      expect(summary.foundAverageMs, isNull);
      expect(database.documentReads, [aggregatePath]);
      expect(database.queries, isEmpty);
      expect(database.documentWrites, isEmpty);
    },
  );

  test('repository missing aggregate has a distinct exception', () async {
    await expectLater(
      ReportRegistrationTimeRepository(firestore: FakeFirestore()).getSummary(),
      throwsA(isA<ReportRegistrationTimeNotGeneratedException>()),
    );
  });

  test('empty nullable summary roundtrips', () {
    final data = registrationSummary(lostCount: 0, foundCount: 0).toMap();
    expect(ReportRegistrationTimeSummary.fromMap(data).toMap(), data);
  });

  test('malformed aggregate rejected instead of fabricating averages', () {
    for (final changes in <Map<String, dynamic>>[
      {'sampleCount': -1},
      {'sampleCount': 1},
      {'lostCount': '2'},
      {'averageMs': null},
      {'averageMs': double.nan},
      {'lostAverageMs': -1},
      {'foundAverageMs': double.infinity},
    ]) {
      expect(
        () => ReportRegistrationTimeSummary.fromMap({
          ...registrationSummary().toMap(),
          ...changes,
        }),
        throwsFormatException,
      );
    }
    final missing = registrationSummary().toMap()..remove('averageMs');
    expect(
      () => ReportRegistrationTimeSummary.fromMap(missing),
      throwsFormatException,
    );
  });
}
