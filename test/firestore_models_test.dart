import 'package:campusfind_flutter/core/models/found_item.dart';
import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/features/matching/services/basic_matching_strategy.dart';
import 'package:campusfind_flutter/features/matching/services/matching_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final _reportedAt = DateTime.utc(2026, 9, 1, 12);

void main() {
  group('LostReport.fromFirestore', () {
    test('parses the existing document shape with a separate document ID', () {
      final data = _lostData();
      final report = LostReport.fromFirestore('lost_test_001', data);

      expect(report.id, 'lost_test_001');
      expect(data.containsKey('id'), isFalse);
      expect(report.ownerUid, 'student-1');
      expect(report.category, 'electronics');
      expect(report.title, 'Scientific calculator');
      expect(report.description, '');
      expect(report.status, 'reported');
      expect(report.locationName, 'ML');
      expect(report.latitude, 4.6);
      expect(report.longitude, -74.0);
      expect(report.longitude, isA<double>());
      expect(report.reportedAt.toUtc(), _reportedAt);
      expect(report.statusChangedAt?.toUtc(), _reportedAt);
      expect(report.imageUrl, isNull);
      expect(report.foundAt, isNull);
      expect(report.readyForPickupAt, isNull);
      expect(report.claimedAt, isNull);
      expect(report.closedAt, isNull);
    });

    for (final explicitNull in [false, true]) {
      test('accepts ${explicitNull ? 'null' : 'absent'} optional fields', () {
        final data = _lostData();
        for (final field in [
          'imageUrl',
          'latitude',
          'longitude',
          'statusChangedAt',
          'foundAt',
          'readyForPickupAt',
          'claimedAt',
          'closedAt',
        ]) {
          if (explicitNull) {
            data[field] = null;
          } else {
            data.remove(field);
          }
        }

        final report = LostReport.fromFirestore('lost_test_001', data);

        expect(report.imageUrl, isNull);
        expect(report.latitude, isNull);
        expect(report.longitude, isNull);
        expect(report.statusChangedAt, isNull);
        expect(report.foundAt, isNull);
        expect(report.readyForPickupAt, isNull);
        expect(report.claimedAt, isNull);
        expect(report.closedAt, isNull);
        expect(report.reportedAt.toUtc(), _reportedAt);
      });
    }

    test('parses image and distinct lifecycle timestamps when present', () {
      final foundAt = _reportedAt.add(const Duration(days: 1));
      final readyAt = _reportedAt.add(const Duration(days: 2));
      final claimedAt = _reportedAt.add(const Duration(days: 3));
      final closedAt = _reportedAt.add(const Duration(days: 4));
      final report = LostReport.fromFirestore('lost_test_001', {
        ..._lostData(),
        'id': 'ignored-field-id',
        'imageUrl': 'https://example.com/lost.jpg',
        'status': 'closed',
        'statusChangedAt': Timestamp.fromDate(closedAt),
        'foundAt': Timestamp.fromDate(foundAt),
        'readyForPickupAt': Timestamp.fromDate(readyAt),
        'claimedAt': Timestamp.fromDate(claimedAt),
        'closedAt': Timestamp.fromDate(closedAt),
      });

      expect(report.id, 'lost_test_001');
      expect(report.imageUrl, 'https://example.com/lost.jpg');
      expect(report.status, 'closed');
      expect(report.statusChangedAt?.toUtc(), closedAt);
      expect(report.foundAt?.toUtc(), foundAt);
      expect(report.readyForPickupAt?.toUtc(), readyAt);
      expect(report.claimedAt?.toUtc(), claimedAt);
      expect(report.closedAt?.toUtc(), closedAt);
    });
  });

  group('FoundItem.fromFirestore', () {
    test('parses the existing document shape without an image', () {
      final data = _foundData();
      final item = FoundItem.fromFirestore('found_test_001', data);

      expect(item.id, 'found_test_001');
      expect(data.containsKey('id'), isFalse);
      expect(item.reporterUid, 'student-2');
      expect(item.category, 'electronics');
      expect(item.title, 'Casio scientific calculator');
      expect(item.publicDescription, '');
      expect(item.status, 'available');
      expect(item.locationName, 'ML');
      expect(item.latitude, 4.6);
      expect(item.longitude, -74.0);
      expect(item.longitude, isA<double>());
      expect(item.semesterId, '2026-2');
      expect(item.donationEligible, isFalse);
      expect(item.donationStatus, 'not_eligible');
      expect(item.createdAt.toUtc(), _reportedAt);
      expect(item.imageUrl, isNull);
    });

    for (final explicitNull in [false, true]) {
      test('accepts ${explicitNull ? 'null' : 'absent'} optional fields', () {
        final data = _foundData();
        for (final field in ['imageUrl', 'latitude', 'longitude']) {
          if (explicitNull) {
            data[field] = null;
          } else {
            data.remove(field);
          }
        }

        final item = FoundItem.fromFirestore('found_test_001', data);

        expect(item.imageUrl, isNull);
        expect(item.latitude, isNull);
        expect(item.longitude, isNull);
        expect(item.createdAt.toUtc(), _reportedAt);
      });
    }

    test('uses the supplied document ID and parses an optional image', () {
      final item = FoundItem.fromFirestore('found_test_001', {
        ..._foundData(),
        'id': 'ignored-field-id',
        'imageUrl': 'https://example.com/found.jpg',
      });

      expect(item.id, 'found_test_001');
      expect(item.imageUrl, 'https://example.com/found.jpg');
    });
  });

  test(
    'parsed reports can be matched locally without Firebase initialization',
    () {
      final lost = LostReport.fromFirestore('lost_test_001', _lostData());
      final found = FoundItem.fromFirestore('found_test_001', _foundData());
      const service = MatchingService(strategy: BasicMatchingStrategy());

      final results = service.findPossibleMatches(lost, [found]);

      expect(results.single.foundItem, same(found));
      expect(results.single.score, closeTo(0.95, 1e-12));
      expect(lost.status, 'reported');
    },
  );
}

// Local fixtures use the supplied field shapes; no database is accessed.
Map<String, dynamic> _lostData() => {
  'ownerUid': 'student-1',
  'category': 'electronics',
  'description': '',
  'latitude': 4.6,
  'longitude': -74,
  'locationName': 'ML',
  'reportedAt': Timestamp.fromDate(_reportedAt),
  'status': 'reported',
  'statusChangedAt': Timestamp.fromDate(_reportedAt),
  'title': 'Scientific calculator',
};

Map<String, dynamic> _foundData() => {
  'reporterUid': 'student-2',
  'category': 'electronics',
  'publicDescription': '',
  'latitude': 4.6,
  'longitude': -74,
  'locationName': 'ML',
  'createdAt': Timestamp.fromDate(_reportedAt),
  'semesterId': '2026-2',
  'donationEligible': false,
  'donationStatus': 'not_eligible',
  'status': 'available',
  'title': 'Casio scientific calculator',
};
