import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';

class FeatureCount {
  const FeatureCount(this.feature, this.count);

  final AppFeature feature;
  final int count;
}

// analytics/featureUsage, written every hour by the aggregateFeatureUsage
// Cloud Function from the featureUsageEvents collection.
class FeatureUsageSummary {
  const FeatureUsageSummary({
    required this.eventCount,
    required this.ranking,
    required this.last7Days,
    required this.byPlatform,
    this.computedAt,
  });

  final int eventCount;

  // All features, most used first.
  final List<FeatureCount> ranking;
  final Map<AppFeature, int> last7Days;

  // platform (flutter | kotlin) -> total events on that platform.
  final Map<String, int> byPlatform;
  final DateTime? computedAt;

  FeatureCount? get mostUsed =>
      ranking.isNotEmpty && ranking.first.count > 0 ? ranking.first : null;

  double shareOf(FeatureCount item) =>
      eventCount == 0 ? 0 : item.count / eventCount;

  factory FeatureUsageSummary.fromMap(
    Map<String, dynamic> data, {
    DateTime? computedAt,
  }) {
    int asCount(Object? value) =>
        value is num && value >= 0 ? value.toInt() : 0;

    final ranking = <FeatureCount>[];
    for (final entry in data['ranking'] as List? ?? const []) {
      if (entry is! Map) continue;
      final feature = AppFeature.fromId('${entry['feature']}');
      if (feature != null) {
        ranking.add(FeatureCount(feature, asCount(entry['count'])));
      }
    }
    ranking.sort((a, b) => b.count.compareTo(a.count));

    final last7Days = <AppFeature, int>{};
    (data['last7Days'] as Map? ?? const {}).forEach((id, count) {
      final feature = AppFeature.fromId('$id');
      if (feature != null) last7Days[feature] = asCount(count);
    });

    final byPlatform = <String, int>{};
    (data['byPlatform'] as Map? ?? const {}).forEach((platform, counts) {
      if (counts is Map) {
        byPlatform['$platform'] = counts.values.fold(
          0,
          (sum, count) => sum + asCount(count),
        );
      }
    });

    return FeatureUsageSummary(
      eventCount: asCount(data['eventCount']),
      ranking: ranking,
      last7Days: last7Days,
      byPlatform: byPlatform,
      computedAt: computedAt,
    );
  }
}
