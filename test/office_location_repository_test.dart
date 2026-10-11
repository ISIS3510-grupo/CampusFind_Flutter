import 'package:campusfind_flutter/features/drop_off/data/office_location_repository.dart';
import 'package:campusfind_flutter/features/drop_off/domain/office_location.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';

void main() {
  const data = {
    'name': 'Mario Laserna',
    'active': true,
    'code': 'ml',
    'radiusMeters': 100,
  };

  test('parses office fields and numeric coordinates', () {
    final office = OfficeLocation.fromFirestore('office-test', {
      ...data,
      'latitude': 4,
      'longitude': -74.06,
    });
    expect(office.id, 'office-test');
    expect(office.name, 'Mario Laserna');
    expect(office.latitude, 4.0);
    expect(office.longitude, -74.06);
    expect(office.hasCoordinates, isTrue);
  });

  test('optional fields may be absent, null, or malformed', () {
    for (final optional in <Map<String, dynamic>>[
      {},
      {'latitude': null, 'longitude': null},
      {'latitude': '4', 'longitude': double.infinity},
    ]) {
      final office = OfficeLocation.fromFirestore('office-test', {
        ...data,
        ...optional,
      });
      expect(office.latitude, isNull);
      expect(office.longitude, isNull);
      expect(office.hasCoordinates, isFalse);
    }
  });

  test('trims the name without requiring extra description fields', () {
    final office = OfficeLocation.fromFirestore('office-test', {
      'name': ' Office ',
    });
    expect(office.name, 'Office');
  });

  test('out-of-range coordinates are omitted', () {
    final office = OfficeLocation.fromFirestore('office-test', {
      ...data,
      'latitude': 91,
      'longitude': -181,
    });
    expect(office.latitude, isNull);
    expect(office.longitude, isNull);
  });

  test('required office information is never invented', () {
    for (final invalid in <Map<String, dynamic>>[
      {},
      {'name': 42},
      {...data, 'name': ''},
    ]) {
      expect(
        () => OfficeLocation.fromFirestore('office-test', invalid),
        throwsFormatException,
      );
    }
  });

  test('reads only the configured office document without writes', () async {
    final database = FakeFirestore(
      documents: {'officeLocations/office-test': data},
    );
    final office = await OfficeLocationRepository(
      officeId: 'office-test',
      firestore: database,
    ).getOfficeLocation();
    expect(office?.name, 'Mario Laserna');
    expect(database.documentReads, ['officeLocations/office-test']);
    expect(database.queries, isEmpty);
    expect(database.documentWrites, isEmpty);
  });

  test(
    'defaults to ml and reads coordinates from the shared contract',
    () async {
      final database = FakeFirestore(
        documents: {
          'officeLocations/ml': {
            ...data,
            'latitude': 4.60275,
            'longitude': -74.06482,
          },
        },
      );
      final office = await OfficeLocationRepository(firestore: database)
          .getOfficeLocation();
      expect(office?.name, 'Mario Laserna');
      expect(office?.latitude, 4.60275);
      expect(office?.longitude, -74.06482);
      expect(database.documentReads, ['officeLocations/ml']);
      expect(database.documentWrites, isEmpty);
    },
  );

  test('missing office document returns null', () async {
    final repository = OfficeLocationRepository(
      officeId: 'missing',
      firestore: FakeFirestore(),
    );
    expect(await repository.getOfficeLocation(), isNull);
  });

  test('backend errors propagate', () async {
    final error = StateError('Offline');
    final repository = OfficeLocationRepository(
      officeId: 'office-test',
      firestore: FakeFirestore(errors: {'officeLocations/office-test': error}),
    );
    await expectLater(repository.getOfficeLocation(), throwsA(same(error)));
  });

  test(
    'empty or nested document IDs are rejected without Firestore access',
    () async {
      for (final id in ['', '  ', 'office/nested']) {
        final database = FakeFirestore();
        await expectLater(
          OfficeLocationRepository(
            officeId: id,
            firestore: database,
          ).getOfficeLocation(),
          throwsArgumentError,
        );
        expect(database.documentReads, isEmpty);
      }
    },
  );
}
