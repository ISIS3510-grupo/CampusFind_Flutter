import 'package:flutter/foundation.dart';

import 'package:campusfind_flutter/features/analytics/data/feature_usage_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_summary.dart';

// ViewModel of the "Most used features" panel.
class FeatureUsageController extends ChangeNotifier {
  FeatureUsageController(this._repository);

  final FeatureUsageRepository _repository;

  FeatureUsageSummary? summary;
  bool loading = false;
  String? errorMessage;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      summary = await _repository.getSummary();
      if (summary == null) {
        errorMessage = 'No usage has been aggregated yet.';
      }
    } catch (_) {
      errorMessage = 'Unable to load feature usage. Please try again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
