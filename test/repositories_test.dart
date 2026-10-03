import 'package:campusfind_flutter/core/data/found_item_repository.dart';
import 'package:campusfind_flutter/core/data/lost_report_repository.dart';
import 'package:campusfind_flutter/features/matching/data/matching_config_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';

void main() {
  group('LostReportRepository', () {
    test(
      'queries only the requested owner and picks the newest nonclosed report',
      () async {
        final database = FakeFirestore(
          documents: {
            'lostReports/older': lostReportData(
              reportedAt: DateTime(2026, 9, 1),
            ),
            'lostReports/closed': lostReportData(
              status: 'closed',
              reportedAt: DateTime(2026, 9, 30),
            ),
            'lostReports/newest': lostReportData(
              reportedAt: DateTime(2026, 9, 20),
            ),
            'lostReports/another-user': lostReportData(
              ownerUid: 'student-2',
              reportedAt: DateTime(2026, 10, 1),
            ),
          },
        );
        final repository = LostReportRepository(firestore: database);

        final report = await repository.getActiveReport('student-1');

        expect(report?.id, 'newest');
        expect(report?.ownerUid, 'student-1');
        expect(database.queries, [
          {
            'collection': 'lostReports',
            'field': 'ownerUid',
            'isEqualTo': 'student-1',
          },
        ]);
      },
    );

    test('returns null for no reports or only closed reports', () async {
      for (final documents in <Map<String, Map<String, dynamic>>>[
        {},
        {'lostReports/closed': lostReportData(status: 'closed')},
      ]) {
        final repository = LostReportRepository(
          firestore: FakeFirestore(documents: documents),
        );
        expect(await repository.getActiveReport('student-1'), isNull);
      }
    });

    test('all statuses except closed remain eligible', () async {
      for (final status in [
        'reported',
        'found',
        'ready_for_pickup',
        'claimed',
      ]) {
        final repository = LostReportRepository(
          firestore: FakeFirestore(
            documents: {'lostReports/report': lostReportData(status: status)},
          ),
        );
        expect((await repository.getActiveReport('student-1'))?.status, status);
      }
    });

    test('an empty UID does not issue a query', () async {
      final database = FakeFirestore();
      final repository = LostReportRepository(firestore: database);
      expect(await repository.getActiveReport(' '), isNull);
      expect(database.queries, isEmpty);
    });

    test('read failures propagate to the caller', () async {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final repository = LostReportRepository(
        firestore: FakeFirestore(errors: {'lostReports': error}),
      );
      await expectLater(
        repository.getActiveReport('student-1'),
        throwsA(same(error)),
      );
    });
  });

  group('FoundItemRepository', () {
    test(
      'queries available items and excludes claimed and donated items',
      () async {
        final database = FakeFirestore(
          documents: {
            'foundItems/available': foundItemData(),
            'foundItems/claimed': foundItemData(status: 'claimed'),
            'foundItems/donated': foundItemData(status: 'donated'),
          },
        );
        final items = await FoundItemRepository(firestore: database)
            .getAvailableItems();

        expect(items.single.id, 'available');
        expect(
          items.single.publicDescription,
          'Black Casio scientific calculator found',
        );
        expect(database.queries, [
          {
            'collection': 'foundItems',
            'field': 'status',
            'isEqualTo': 'available',
          },
        ]);
        expect(database.documentReads, isEmpty);
      },
    );
  });

  group('MatchingConfigRepository', () {
    for (final value in [0, 0.70, 0.85, 1]) {
      test('accepts valid threshold $value', () async {
        final database = FakeFirestore(
          documents: {
            'appConfig/general': {'matchingThreshold': value},
          },
        );
        final repository = MatchingConfigRepository(firestore: database);
        expect(await repository.getMatchingThreshold(), value.toDouble());
        expect(database.documentReads, ['appConfig/general']);
      });
    }

    test('falls back to 0.70 when the document or field is absent', () async {
      for (final documents in <Map<String, Map<String, dynamic>>>[
        {},
        {'appConfig/general': {}},
      ]) {
        final repository = MatchingConfigRepository(
          firestore: FakeFirestore(documents: documents),
        );
        expect(await repository.getMatchingThreshold(), 0.70);
      }
    });

    test(
      'falls back for null, nonnumeric, nonfinite and out of range values',
      () async {
        for (final value in [
          null,
          '0.85',
          true,
          -0.1,
          1.1,
          double.nan,
          double.infinity,
        ]) {
          final repository = MatchingConfigRepository(
            firestore: FakeFirestore(
              documents: {
                'appConfig/general': {'matchingThreshold': value},
              },
            ),
          );
          expect(await repository.getMatchingThreshold(), 0.70);
        }
      },
    );

    test('falls back to 0.70 when reading configuration fails', () async {
      final repository = MatchingConfigRepository(
        firestore: FakeFirestore(
          errors: {
            'appConfig/general': FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            ),
          },
        ),
      );
      expect(await repository.getMatchingThreshold(), 0.70);
    });
  });
}
