import 'package:flutter/foundation.dart';

import '../data/report_bottleneck_repository.dart';
import '../domain/report_bottleneck_summary.dart';

class AnalyticsViewModel extends ChangeNotifier {
  AnalyticsViewModel({this._repository = const ReportBottleneckRepository()});

  final ReportBottleneckRepository _repository;
  ReportBottleneckSummary? _bottleneckSummary;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  ReportBottleneckSummary? get bottleneckSummary => _bottleneckSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadReportBottleneck() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    _bottleneckSummary = null;
    notifyListeners();

    try {
      final summary = await _repository.getSummary();
      if (!_disposed) _bottleneckSummary = summary;
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
