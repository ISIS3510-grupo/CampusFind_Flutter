import 'dart:math' as math;

import '../../../core/models/found_item.dart';
import '../../../core/models/lost_report.dart';
import '../domain/matching_strategy.dart';

class BasicMatchingStrategy implements MatchingStrategy {
  const BasicMatchingStrategy();

  @override
  double calculateScore(LostReport lost, FoundItem found) {
    final categoryScore =
        _normalize(lost.category) == _normalize(found.category) ? 1.0 : 0.0;
    final locationScore = _locationScore(lost, found);
    final dateScore = _dateScore(lost.reportedAt, found.createdAt);
    final textScore = _textScore(
      '${lost.title} ${lost.description}',
      '${found.title} ${found.publicDescription}',
    );

    return (categoryScore * 0.40 +
            locationScore * 0.25 +
            dateScore * 0.20 +
            textScore * 0.15)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String _normalize(String value) => value.toLowerCase().trim();

  double _locationScore(LostReport lost, FoundItem found) {
    final lostLocation = _normalize(lost.locationName);
    final foundLocation = _normalize(found.locationName);
    if (lostLocation.isNotEmpty && lostLocation == foundLocation) return 1.0;

    if (!_validCoordinates(lost.latitude, lost.longitude) ||
        !_validCoordinates(found.latitude, found.longitude)) {
      return 0.0;
    }

    final distance = _distanceInMeters(
      lost.latitude!,
      lost.longitude!,
      found.latitude!,
      found.longitude!,
    );
    if (distance <= 100) return 1.0;
    if (distance <= 300) return 0.8;
    if (distance <= 700) return 0.5;
    if (distance <= 1500) return 0.2;
    return 0.0;
  }

  bool _validCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double _distanceInMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadius = 6371000.0;
    const radians = math.pi / 180;
    final latitudeDifference = (latitude2 - latitude1) * radians;
    final longitudeDifference = (longitude2 - longitude1) * radians;
    final a =
        math.pow(math.sin(latitudeDifference / 2), 2) +
        math.cos(latitude1 * radians) *
            math.cos(latitude2 * radians) *
            math.pow(math.sin(longitudeDifference / 2), 2);
    // Clamp rounding errors before taking the square roots.
    final boundedA = a.clamp(0.0, 1.0);
    return earthRadius *
        2 *
        math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));
  }

  double _dateScore(DateTime reportedAt, DateTime createdAt) {
    final days = reportedAt.difference(createdAt).abs().inDays;
    if (days <= 1) return 1.0;
    if (days <= 3) return 0.75;
    if (days <= 7) return 0.40;
    return 0.0;
  }

  double _textScore(String lostText, String foundText) {
    final lostWords = _words(lostText);
    final foundWords = _words(foundText);
    final union = lostWords.union(foundWords);
    if (union.isEmpty) return 0.0;
    return lostWords.intersection(foundWords).length / union.length;
  }

  Set<String> _words(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 3)
        .toSet();
  }
}
