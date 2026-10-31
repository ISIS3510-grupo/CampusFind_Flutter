import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_tracker.dart';

class FakeFeatureUsageTracker implements FeatureUsageTracker {
  final List<AppFeature> tracked = [];
  final Map<AppFeature, Duration?> responseTimes = {};

  @override
  void track(AppFeature feature, {Duration? responseTime}) {
    tracked.add(feature);
    responseTimes[feature] = responseTime;
  }
}
