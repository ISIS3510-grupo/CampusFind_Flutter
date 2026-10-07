import 'dart:math';

import 'package:campusfind_flutter/models/campus_locations.dart';
import 'package:campusfind_flutter/models/uniandes_buildings.dart';
import 'package:campusfind_flutter/services/campus_building_locator.dart';
import 'package:campusfind_flutter/services/location_service.dart';
import 'package:campusfind_flutter/viewmodels/item_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

// Meters per degree of latitude, and of longitude at the campus latitude.
const _mLat = 111320.0;
final _mLng = 111320.0 * cos(4.6015 * pi / 180);

/// Moves a point [north] and [east] meters.
(double, double) _offset(
  (double, double) point, {
  double north = 0,
  double east = 0,
}) => (point.$1 + north / _mLat, point.$2 + east / _mLng);

CampusLocation _building(String id) =>
    uniandesBuildings.singleWhere((building) => building.id == id);

void main() {
  // A 20 m x 20 m building whose south-west corner is at the origin.
  const origin = (4.6000, -74.0650);
  final square = CampusLocation(
    id: 'SQ',
    name: 'Square',
    latitude: origin.$1 + 10 / _mLat,
    longitude: origin.$2 + 10 / _mLng,
    outline: [
      origin,
      _offset(origin, east: 20),
      _offset(origin, north: 20, east: 20),
      _offset(origin, north: 20),
    ],
  );

  group('distanceToFootprint', () {
    test('is zero inside the outline', () {
      final (lat, lng) = _offset(origin, north: 5, east: 15);
      expect(square.distanceToFootprint(lat, lng), 0);
    });

    test('measures to the closest wall outside the outline', () {
      final (lat, lng) = _offset(origin, north: 10, east: 32);
      expect(square.distanceToFootprint(lat, lng), closeTo(12, 0.05));
    });

    test('measures to the closest corner diagonally', () {
      final (lat, lng) = _offset(origin, north: -3, east: -4);
      expect(square.distanceToFootprint(lat, lng), closeTo(5, 0.05));
    });

    test('falls back to the centroid without an outline', () {
      const point = CampusLocation(
        id: 'P',
        name: 'Point',
        latitude: 4.6,
        longitude: -74.065,
      );
      expect(point.distanceToFootprint(4.6, -74.065), 0);
    });
  });

  group('CampusBuildingLocator thresholds', () {
    final locator = CampusBuildingLocator(buildings: [square]);

    BuildingMatch matchAt({
      required double north,
      required double east,
      required double accuracy,
    }) {
      final (lat, lng) = _offset(origin, north: north, east: east);
      return locator
          .locate(latitude: lat, longitude: lng, accuracyMeters: accuracy)
          .match;
    }

    test('a point inside with a good fix is inside', () {
      expect(matchAt(north: 10, east: 10, accuracy: 8), BuildingMatch.inside);
    });

    test('a point within the GPS error of the wall is near', () {
      expect(matchAt(north: 10, east: 45, accuracy: 30), BuildingMatch.near);
    });

    test('the error margin never goes below 10 m', () {
      expect(matchAt(north: 10, east: 28, accuracy: 3), BuildingMatch.near);
      expect(matchAt(north: 10, east: 32, accuracy: 3), BuildingMatch.unknown);
    });

    test('the error margin never goes above 40 m', () {
      expect(matchAt(north: 10, east: 65, accuracy: 70), BuildingMatch.unknown);
    });

    test('a reading coarser than 75 m is never trusted, even inside', () {
      expect(
        matchAt(north: 10, east: 10, accuracy: 120),
        BuildingMatch.unknown,
      );
    });

    test('a missing accuracy uses the widest usable margin', () {
      expect(matchAt(north: 10, east: 10, accuracy: 0), BuildingMatch.inside);
      expect(
        matchAt(north: 10, east: 10, accuracy: double.nan),
        BuildingMatch.inside,
      );
    });

    test('an empty campus detects nothing', () {
      final detection = const CampusBuildingLocator(buildings: [])
          .locate(latitude: 4.6, longitude: -74.065, accuracyMeters: 5);
      expect(detection.match, BuildingMatch.unknown);
      expect(detection.building, isNull);
      expect(detection.ranked, isEmpty);
    });
  });

  group('Uniandes building data', () {
    test('has unique codes and names', () {
      final ids = uniandesBuildings.map((b) => b.id).toSet();
      final names = uniandesBuildings.map((b) => b.name).toSet();
      expect(ids, hasLength(uniandesBuildings.length));
      expect(names, hasLength(uniandesBuildings.length));
    });

    test('every building has an outline inside the campus area', () {
      for (final building in uniandesBuildings) {
        expect(
          building.outline.length,
          greaterThanOrEqualTo(3),
          reason: building.id,
        );
        for (final (lat, lng) in building.outline) {
          expect(lat, inInclusiveRange(4.598, 4.606), reason: building.id);
          expect(lng, inInclusiveRange(-74.068, -74.061), reason: building.id);
        }
      }
    });

    test('every centroid falls inside its own building', () {
      for (final building in uniandesBuildings) {
        expect(
          building.distanceToFootprint(building.latitude, building.longitude),
          0,
          reason: building.id,
        );
      }
    });

    test('the picker list is sorted by name', () {
      final names = defaultUniandesLocations.map((b) => b.name).toList();
      expect(names, [...names]..sort());
    });
  });

  group('Real campus positions', () {
    final locator = CampusBuildingLocator(buildings: uniandesBuildings);

    for (final id in ['ML', 'SD', 'W', 'LL', 'Rgd', 'Au', 'Ga', 'C']) {
      test('the middle of $id is detected as $id', () {
        final building = _building(id);
        final detection = locator.locate(
          latitude: building.latitude,
          longitude: building.longitude,
          accuracyMeters: 15,
        );
        expect(detection.match, BuildingMatch.inside);
        expect(detection.building?.id, id);
      });
    }

    test('the coordinates the app used before are not in those buildings', () {
      // Old hard-coded points: SD sat 385 m away, by building Q.
      final detection = locator.locate(
        latitude: 4.600980,
        longitude: -74.065830,
        accuracyMeters: 10,
      );
      expect(detection.building?.id, isNot('SD'));
    });

    test('a point off campus detects no building but still ranks them', () {
      // Teatro México, Calle 19 with Carrera 5.
      final detection = locator.locate(
        latitude: 4.60712,
        longitude: -74.07007,
        accuracyMeters: 10,
      );
      expect(detection.match, BuildingMatch.unknown);
      expect(detection.building, isNull);
      expect(detection.ranked, hasLength(uniandesBuildings.length));
      expect(detection.distanceMeters, greaterThan(100));
    });
  });

  group('ItemViewModel building detection', () {
    test('preselects the building the student is in', () async {
      final sd = _building('SD');
      final viewModel = ItemViewModel(
        locationService: _FakeLocation(
          _FakePosition(sd.latitude, sd.longitude, 12),
        ),
      );

      await viewModel.loadPrioritizedLocations();

      expect(viewModel.buildingMatch, BuildingMatch.inside);
      expect(viewModel.selectedLocation?.id, 'SD');
      expect(viewModel.locations.first.id, 'SD');
      expect(viewModel.isLoadingLocation, isFalse);
    });

    test('does not preselect anything off campus', () async {
      final viewModel = ItemViewModel(
        locationService: _FakeLocation(_FakePosition(4.60712, -74.07007, 10)),
      );

      await viewModel.loadPrioritizedLocations();

      expect(viewModel.buildingMatch, BuildingMatch.unknown);
      expect(viewModel.selectedLocation, isNull);
    });

    test(
      'without GPS keeps the alphabetical list and selects nothing',
      () async {
        final viewModel = ItemViewModel(
          locationService: _FakeLocation(null, error: 'GPS off'),
        );

        await viewModel.loadPrioritizedLocations();

        expect(viewModel.buildingMatch, BuildingMatch.unknown);
        expect(viewModel.selectedLocation, isNull);
        expect(viewModel.locations, defaultUniandesLocations);
        expect(viewModel.isLoadingLocation, isFalse);
      },
    );
  });
}

class _FakeLocation extends LocationService {
  _FakeLocation(this.position, {this.error});
  final Position? position;
  final Object? error;

  @override
  Future<Position> getCurrentLocation() async {
    if (error != null) throw error!;
    return position!;
  }
}

class _FakePosition extends Fake implements Position {
  _FakePosition(this.latitude, this.longitude, this.accuracy);
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final double accuracy;
}
