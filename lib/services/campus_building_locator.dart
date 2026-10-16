import 'dart:math';

import '../models/campus_locations.dart';

/// How sure the app is about the building the student is in.
enum BuildingMatch {
  /// The GPS point falls inside the building outline.
  inside,

  /// The point is outside every outline but within the GPS error of this
  /// building, which is normal indoors where the signal drifts.
  near,

  /// Too far from every building, or the GPS reading is too coarse to tell
  /// buildings apart: the student picks the place by hand.
  unknown,
}

class BuildingDetection {
  const BuildingDetection({
    required this.match,
    required this.building,
    required this.distanceMeters,
    required this.ranked,
  });

  final BuildingMatch match;

  /// Detected building; null when [match] is [BuildingMatch.unknown].
  final CampusLocation? building;

  /// Meters from the GPS point to the outline of the closest building.
  final double distanceMeters;

  /// Every building, closest outline first.
  final List<CampusLocation> ranked;
}

/// Tells which campus building a GPS point belongs to from the building
/// outlines, so it works offline and without any paid map API.
class CampusBuildingLocator {
  const CampusBuildingLocator({
    required this.buildings,
    this.minToleranceMeters = 10,
    this.maxToleranceMeters = 40,
    this.maxUsableAccuracyMeters = 75,
  });

  final List<CampusLocation> buildings;

  /// Smallest margin around an outline that still counts as "in" it, for
  /// points that land on a wall or a doorway.
  final double minToleranceMeters;

  /// Largest margin: neighbouring Uniandes buildings are often less than
  /// 40 m apart, so a wider margin would pick the wrong one.
  final double maxToleranceMeters;

  /// Readings worse than this cannot separate buildings at all.
  final double maxUsableAccuracyMeters;

  BuildingDetection locate({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) {
    final distances = {
      for (final building in buildings)
        building: building.distanceToFootprint(latitude, longitude),
    };
    final ranked = [...buildings]
      ..sort((a, b) => distances[a]!.compareTo(distances[b]!));
    if (ranked.isEmpty) {
      return const BuildingDetection(
        match: BuildingMatch.unknown,
        building: null,
        distanceMeters: double.infinity,
        ranked: [],
      );
    }

    final closest = ranked.first;
    final distance = distances[closest]!;
    final accuracy = accuracyMeters.isFinite && accuracyMeters > 0
        ? accuracyMeters
        : maxUsableAccuracyMeters;
    final tolerance = min(
      max(accuracy, minToleranceMeters),
      maxToleranceMeters,
    );

    final BuildingMatch match;
    if (accuracy > maxUsableAccuracyMeters) {
      match = BuildingMatch.unknown;
    } else if (distance == 0) {
      match = BuildingMatch.inside;
    } else if (distance <= tolerance) {
      match = BuildingMatch.near;
    } else {
      match = BuildingMatch.unknown;
    }

    return BuildingDetection(
      match: match,
      building: match == BuildingMatch.unknown ? null : closest,
      distanceMeters: distance,
      ranked: ranked,
    );
  }
}
