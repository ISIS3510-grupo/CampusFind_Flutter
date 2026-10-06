import 'package:flutter/foundation.dart';

import '../data/report_bottleneck_repository.dart';
import '../domain/report_bottleneck_summary.dart';
import '../services/report_bottleneck_aggregation_service.dart';

class ReportBottleneckViewModel extends ChangeNotifier {
  ReportBottleneckViewModel({
    this._repository = const ReportBottleneckRepository(),
    this._aggregationService = const ReportBottleneckAggregationService(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReportBottleneckRepository _repository;
  final ReportBottleneckAggregationService _aggregationService;
  final DateTime Function() _now;
  ReportBottleneckSummary? _summary;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  bool _disposed = false;

  ReportBottleneckSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading || _isRefreshing || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    _summary = null;
    notifyListeners();

    try {
      final summary = await _repository.getSummary();
      if (!_disposed) _summary = summary;
    } on ReportBottleneckNotGeneratedException {
      if (!_disposed) _errorMessage = 'No analytics have been generated yet.';
    } catch (_) {
      if (!_disposed) {
        _errorMessage =
            'Unable to load report bottleneck analytics. Please try again.';
      }
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isLoading || _isRefreshing || _disposed) return;
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _aggregationService.refresh(now: _now());
      if (!_disposed) _summary = result;
    } catch (_) {
      if (!_disposed) {
        _errorMessage = 'Unable to refresh analytics. Please try again.';
      }
    } finally {
      _isRefreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
