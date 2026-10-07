import 'dart:math';

import 'uniandes_buildings.dart';

/// A campus building: its official code, display name, the centroid saved
/// with the report and the outline used to tell where the student is.
class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// OpenStreetMap way the outline comes from, to trace the data back.
  final int? osmWayId;

  /// Building footprint as (latitude, longitude) vertices, not closed.
  final List<(double, double)> outline;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.osmWayId,
    this.outline = const [],
  });

  /// Great-circle distance in meters from a point to the centroid.
  double distanceTo(double lat, double lng) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat - latitude) * p) / 2 +
        cos(latitude * p) * cos(lat * p) * (1 - cos((lng - longitude) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  /// Meters from a point to the building footprint; 0 when the point is
  /// inside it. Buildings without an outline fall back to the centroid.
  double distanceToFootprint(double lat, double lng) {
    if (outline.length < 3) return distanceTo(lat, lng);

    // Local plane centered on the point: at campus scale (< 1 km) the error
    // against the sphere is below a centimeter.
    const metersPerDegree = 111320.0;
    final metersPerLngDegree = metersPerDegree * cos(lat * pi / 180);
    final vertices = [
      for (final (vLat, vLng) in outline)
        ((vLng - lng) * metersPerLngDegree, (vLat - lat) * metersPerDegree),
    ];

    var inside = false;
    var nearest = double.infinity;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final (xi, yi) = vertices[i];
      final (xj, yj) = vertices[j];
      if ((yi > 0) != (yj > 0) && 0 < (xj - xi) * (0 - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      nearest = min(nearest, _distanceToSegment(xi, yi, xj, yj));
    }
    return inside ? 0 : nearest;
  }

  /// Distance from the origin to the segment (x1, y1)-(x2, y2).
  static double _distanceToSegment(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : ((-x1 * dx - y1 * dy) / lengthSquared).clamp(0.0, 1.0);
    return sqrt(pow(x1 + t * dx, 2) + pow(y1 + t * dy, 2));
  }
}

/// Every Uniandes building, sorted by name for the manual picker.
final List<CampusLocation> defaultUniandesLocations = List.unmodifiable(
  [...uniandesBuildings]..sort((a, b) => a.name.compareTo(b.name)),
);
