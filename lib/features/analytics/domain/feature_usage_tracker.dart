import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';

// Records that the student used a feature. Implementations must never throw:
// analytics is not allowed to break or slow down the user flow.
abstract class FeatureUsageTracker {
  void track(AppFeature feature);
}
