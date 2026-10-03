import 'package:flutter/foundation.dart';

import '../data/report_registration_time_repository.dart';
import '../domain/report_registration_time_summary.dart';
import '../services/report_registration_time_aggregation_service.dart';

class ReportRegistrationTimeViewModel extends ChangeNotifier {
  ReportRegistrationTimeViewModel({
    this._repository = const ReportRegistrationTimeRepository(),
    this._aggregationService = const ReportRegistrationTimeAggregationService(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReportRegistrationTimeRepository _repository;
  final ReportRegistrationTimeAggregationService _aggregationService;
  final DateTime Function() _now;
  ReportRegistrationTimeSummary? _summary;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  bool _disposed = false;

  ReportRegistrationTimeSummary? get summary => _summary;
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
      final result = await _repository.getSummary();
      if (!_disposed) _summary = result;
    } on ReportRegistrationTimeNotGeneratedException {
      if (!_disposed) {
        _errorMessage =
            'Registration time analytics have not been generated yet.';
      }
    } catch (_) {
      if (!_disposed) {
        _errorMessage =
            'Unable to load registration time analytics. Please try again.';
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
        _errorMessage =
            'Unable to refresh registration time analytics. Please try again.';
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
