import 'package:flutter/foundation.dart';

import 'package:campusfind_flutter/features/analytics/data/offline_sync_metric_repository_impl.dart';
import 'package:campusfind_flutter/features/analytics/domain/offline_sync_metric_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/offline_sync_summary.dart';
import 'package:campusfind_flutter/features/analytics/services/offline_sync_stats_service.dart';

class OfflineSyncTimeViewModel extends ChangeNotifier {
  OfflineSyncTimeViewModel({
    OfflineSyncMetricRepository? repository,
    OfflineSyncStatsService? statsService,
  }) : _repository = repository ?? const OfflineSyncMetricRepositoryImpl(),
       _statsService = statsService ?? OfflineSyncStatsService();

  final OfflineSyncMetricRepository _repository;
  final OfflineSyncStatsService _statsService;

  OfflineSyncSummary? _summary;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  OfflineSyncSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Reads the recorded recoveries and recalculates the statistics. It keeps
  // the last good summary when a refresh fails.
  Future<void> load() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final samples = await _repository.fetchSamples();
      final result = await _statsService.summarize(samples);
      if (!_disposed) _summary = result;
    } catch (error) {
      debugPrint('Offline sync analytics failed: $error');
      if (!_disposed) {
        _errorMessage = 'Unable to load offline sync analytics. Try again.';
      }
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
