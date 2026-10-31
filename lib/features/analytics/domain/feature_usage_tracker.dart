import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';

// Records that the student used a feature. Implementations must never throw:
// analytics is not allowed to break or slow down the user flow.
//
// [responseTime] is how long the student waited for the app to answer that
// use (BQ Type 5: which features have the longest response times). It is null
// for actions with nothing to wait for.
abstract class FeatureUsageTracker {
  void track(AppFeature feature, {Duration? responseTime});
}
