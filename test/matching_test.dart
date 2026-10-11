import 'package:campusfind_flutter/core/models/found_item.dart';
import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/features/matching/domain/matching_strategy.dart';
import 'package:campusfind_flutter/features/matching/services/basic_matching_strategy.dart';
import 'package:campusfind_flutter/features/matching/services/matching_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _reportedAt = DateTime.utc(2026, 9, 1, 12);

void main() {
  const strategy = BasicMatchingStrategy();

  group('BasicMatchingStrategy', () {
    test('similar calculator items exceed the default threshold', () {
      final lost = _lost(title: 'Scientific calculator', locationName: 'ML');
      final found = _found(
        category: 'electronics',
        title: 'Casio scientific calculator',
        locationName: 'ML',
        createdAt: _reportedAt,
      );

      final score = strategy.calculateScore(lost, found);

      expect(score, closeTo(0.95, 1e-12));
      expect(score, greaterThanOrEqualTo(0.70));
    });

    test('category contributes 0.40 after trimming and lowercasing', () {
      expect(
        strategy.calculateScore(
          _lost(category: ' Electronics '),
          _found(category: 'ELECTRONICS'),
        ),
        closeTo(0.40, 1e-12),
      );
    });

    test('different categories remove the category contribution', () {
      final lost = _lost(title: 'Calculator', locationName: 'ML');
      final matchingCategory = _found(
        category: 'electronics',
        title: 'Calculator',
        locationName: 'ML',
        createdAt: _reportedAt,
      );
      final otherCategory = _found(
        category: 'clothing',
        title: 'Calculator',
        locationName: 'ML',
        createdAt: _reportedAt,
      );

      expect(strategy.calculateScore(lost, matchingCategory), 1.0);
      expect(
        strategy.calculateScore(lost, otherCategory),
        closeTo(0.60, 1e-12),
      );
    });

    test('same normalized location name contributes 0.25', () {
      expect(
        strategy.calculateScore(
          _lost(locationName: ' ML '),
          _found(locationName: 'ml'),
        ),
        closeTo(0.25, 1e-12),
      );
    });

    test('matching location names take priority over distant coordinates', () {
      expect(
        strategy.calculateScore(
          _lost(locationName: 'ML', latitude: 0, longitude: 0),
          _found(locationName: 'ML', latitude: 30, longitude: 30),
        ),
        closeTo(0.25, 1e-12),
      );
    });

    test('blank location names do not count as matching locations', () {
      expect(strategy.calculateScore(_lost(locationName: ' '), _found()), 0.0);
    });

    test('different location names with missing coordinates score zero', () {
      expect(
        strategy.calculateScore(
          _lost(locationName: 'ML'),
          _found(locationName: 'W', latitude: 4.6),
        ),
        0.0,
      );
    });

    // At the equator, these latitude offsets cover each distance band.
    for (final entry in <double, double>{
      0: 1.0,
      0.00045: 1.0,
      0.0018: 0.8,
      0.0045: 0.5,
      0.009: 0.2,
      0.018: 0.0,
    }.entries) {
      test(
        'coordinate offset ${entry.key} uses location score ${entry.value}',
        () {
          expect(
            strategy.calculateScore(
              _lost(locationName: 'ML', latitude: 0, longitude: 0),
              _found(locationName: 'W', latitude: entry.key, longitude: 0),
            ),
            closeTo(entry.value * 0.25, 1e-12),
          );
        },
      );
    }

    test(
      'invalid or incomplete coordinates contribute zero on either side',
      () {
        for (final coordinates in <(double?, double?)>[
          (null, 0),
          (0, null),
          (91, 0),
          (-91, 0),
          (0, 181),
          (0, -181),
          (double.nan, 0),
          (0, double.infinity),
        ]) {
          expect(
            strategy.calculateScore(
              _lost(latitude: 0, longitude: 0),
              _found(latitude: coordinates.$1, longitude: coordinates.$2),
            ),
            0.0,
          );
          expect(
            strategy.calculateScore(
              _lost(latitude: coordinates.$1, longitude: coordinates.$2),
              _found(latitude: 0, longitude: 0),
            ),
            0.0,
          );
        }
      },
    );

    test('antipodal coordinates return a finite score', () {
      final score = strategy.calculateScore(
        _lost(latitude: 90, longitude: 0),
        _found(latitude: -90, longitude: 180),
      );
      expect(score.isFinite, isTrue);
      expect(score, 0.0);
    });

    for (final entry in <int, double>{
      0: 1.0,
      1: 1.0,
      2: 0.75,
      3: 0.75,
      4: 0.40,
      7: 0.40,
      8: 0.0,
      30: 0.0,
    }.entries) {
      test('date difference of ${entry.key} days scores ${entry.value}', () {
        for (final direction in [-1, 1]) {
          expect(
            strategy.calculateScore(
              _lost(),
              _found(
                createdAt: _reportedAt.add(
                  Duration(days: entry.key * direction),
                ),
              ),
            ),
            closeTo(entry.value * 0.20, 1e-12),
          );
        }
      });
    }

    test('date scoring uses complete elapsed days', () {
      expect(
        strategy.calculateScore(
          _lost(),
          _found(createdAt: _reportedAt.add(const Duration(hours: 47))),
        ),
        closeTo(0.20, 1e-12),
      );
    });

    test('similar descriptions increase Jaccard text similarity', () {
      final lost = _lost(
        title: 'Scientific calculator',
        description: 'Black Casio',
      );
      final similar = _found(
        title: 'Casio calculator',
        publicDescription: 'Black scientific calculator',
      );
      final unrelated = _found(
        title: 'Blue umbrella',
        publicDescription: 'Wooden handle',
      );

      expect(strategy.calculateScore(lost, similar), closeTo(0.15, 1e-12));
      expect(strategy.calculateScore(lost, unrelated), 0.0);
    });

    test('text uses intersection divided by union of distinct words', () {
      expect(
        strategy.calculateScore(
          _lost(title: 'black calculator calculator'),
          _found(publicDescription: 'black backpack'),
        ),
        closeTo(0.15 / 3, 1e-12),
      );
    });

    test('text normalizes case, punctuation, whitespace and short words', () {
      expect(
        strategy.calculateScore(
          _lost(title: '  BLACK,Calculator! a an 12 ', description: 'black'),
          _found(publicDescription: 'black\ncalculator'),
        ),
        closeTo(0.15, 1e-12),
      );
    });

    test('text preserves accented words', () {
      expect(
        strategy.calculateScore(
          _lost(description: 'LÁPIZ, azul.'),
          _found(publicDescription: 'lápiz azul'),
        ),
        closeTo(0.15, 1e-12),
      );
    });

    test('empty word sets contribute zero without dividing by zero', () {
      expect(strategy.calculateScore(_lost(), _found()), 0.0);
      expect(
        strategy.calculateScore(
          _lost(title: 'a an !'),
          _found(title: 'to of ?'),
        ),
        0.0,
      );
      expect(
        strategy.calculateScore(_lost(title: 'calculator'), _found()),
        0.0,
      );
    });

    test('scores are deterministic and stay between zero and one', () {
      final lost = _lost(title: 'calculator', locationName: 'ML');
      final found = _found(
        category: 'electronics',
        title: 'calculator',
        locationName: 'ML',
        createdAt: _reportedAt,
      );
      final score = strategy.calculateScore(lost, found);
      expect(score, 1.0);
      expect(strategy.calculateScore(lost, found), score);
      expect(score, inInclusiveRange(0.0, 1.0));
      expect(strategy.calculateScore(_lost(), _found()), 0.0);
    });
  });

  group('MatchingService', () {
    test('compare delegates the same objects to the injected strategy', () {
      final fake = _FakeMatchingStrategy();
      final service = MatchingService(strategy: fake);
      final lost = _lost();
      final found = _found();

      expect(service.compare(lost, found), 0.81);
      expect(fake.lastLost, same(lost));
      expect(fake.comparedItems.single, same(found));
    });

    test(
      'accepts exactly 0.70 and excludes candidates below the threshold',
      () {
        final fake = _FakeMatchingStrategy(
          scores: {'exact': 0.70, 'below': 0.6999},
        );
        final service = MatchingService(strategy: fake);
        final exact = _found(id: 'exact');

        final results = service.findPossibleMatches(_lost(), [
          _found(id: 'below'),
          exact,
        ]);

        expect(service.threshold, 0.70);
        expect(results, hasLength(1));
        expect(results.single.foundItem, same(exact));
        expect(results.single.score, 0.70);
        expect(fake.comparedItems, hasLength(2));
      },
    );

    for (final status in ['claimed', 'donated', 'unknown']) {
      test('ignores $status items without calling the strategy', () {
        final fake = _FakeMatchingStrategy();
        final service = MatchingService(strategy: fake);

        expect(
          service.findPossibleMatches(_lost(), [_found(status: status)]),
          isEmpty,
        );
        expect(fake.comparedItems, isEmpty);
      });
    }

    test(
      'sorts matches highest first and preserves inputs and report status',
      () {
        final fake = _FakeMatchingStrategy(
          scores: {'low': 0.70, 'high': 0.95, 'middle': 0.81},
        );
        final service = MatchingService(strategy: fake);
        final lost = _lost();
        final items = [
          _found(id: 'low'),
          _found(id: 'high'),
          _found(id: 'middle'),
        ];

        final results = service.findPossibleMatches(lost, items);

        expect(results.map((result) => result.score), [0.95, 0.81, 0.70]);
        expect(results.map((result) => result.foundItem.id), [
          'high',
          'middle',
          'low',
        ]);
        expect(items.map((item) => item.id), ['low', 'high', 'middle']);
        expect(lost.status, 'reported');
        expect(items.every((item) => item.status == 'available'), isTrue);
      },
    );

    test('supports a configurable threshold', () {
      final service = MatchingService(
        strategy: _FakeMatchingStrategy(scores: {'below': 0.89, 'exact': 0.90}),
        threshold: 0.90,
      );

      final results = service.findPossibleMatches(_lost(), [
        _found(id: 'below'),
        _found(id: 'exact'),
      ]);

      expect(results.single.foundItem.id, 'exact');
    });

    test('an empty candidate list returns no matches', () {
      final fake = _FakeMatchingStrategy();
      expect(
        MatchingService(strategy: fake).findPossibleMatches(_lost(), []),
        isEmpty,
      );
      expect(fake.comparedItems, isEmpty);
    });

    test('works with the basic strategy for similar calculator reports', () {
      const service = MatchingService(strategy: strategy);
      final results = service.findPossibleMatches(
        _lost(title: 'Scientific calculator', locationName: 'ML'),
        [
          _found(
            category: 'electronics',
            title: 'Casio scientific calculator',
            locationName: 'ML',
            createdAt: _reportedAt,
          ),
        ],
      );
      expect(results.single.score, closeTo(0.95, 1e-12));
    });
  });
}

// Default fixtures differ in category and date to isolate each contribution.
LostReport _lost({
  String category = 'electronics',
  String title = '',
  String description = '',
  String locationName = '',
  double? latitude,
  double? longitude,
}) {
  return LostReport(
    id: 'lost-1',
    ownerUid: 'student-1',
    category: category,
    title: title,
    description: description,
    status: 'reported',
    locationName: locationName,
    latitude: latitude,
    longitude: longitude,
    reportedAt: _reportedAt,
  );
}

FoundItem _found({
  String id = 'found-1',
  String category = 'clothing',
  String title = '',
  String publicDescription = '',
  String status = 'available',
  String locationName = '',
  double? latitude,
  double? longitude,
  DateTime? createdAt,
}) {
  return FoundItem(
    id: id,
    reporterUid: 'student-2',
    category: category,
    title: title,
    publicDescription: publicDescription,
    status: status,
    locationName: locationName,
    latitude: latitude,
    longitude: longitude,
    semesterId: '2026-2',
    donationEligible: false,
    donationStatus: 'not_eligible',
    createdAt: createdAt ?? _reportedAt.add(const Duration(days: 30)),
  );
}

class _FakeMatchingStrategy implements MatchingStrategy {
  _FakeMatchingStrategy({this.scores = const {}});

  final Map<String, double> scores;
  final comparedItems = <FoundItem>[];
  LostReport? lastLost;

  @override
  double calculateScore(LostReport lost, FoundItem found) {
    lastLost = lost;
    comparedItems.add(found);
    return scores[found.id] ?? 0.81;
  }
}
