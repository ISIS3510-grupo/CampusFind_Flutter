import 'package:flutter/foundation.dart';

import 'package:campusfind_flutter/features/analytics/services/report_registration_performance_tracker.dart';
import 'package:campusfind_flutter/features/reports/data/photo_labeler.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';
import 'package:campusfind_flutter/features/reports/domain/photo_suggestion.dart';

// Keeps the form state; the screen only renders it and forwards user actions.
class ReportLostItemController extends ChangeNotifier {
  ReportLostItemController(
    this._repository, {
    this._photoLabeler,
    this._tracker = const ReportRegistrationPerformanceTracker(),
  });

  final LostReportRepository _repository;
  final ReportRegistrationPerformanceTracker _tracker;
  final PhotoLabeler? _photoLabeler;
  bool _disposed = false;

  List<String> categories = const [];
  bool loadingCategories = true;
  bool submitting = false;
  String? errorMessage;
  bool analyzingPhoto = false;
  PhotoSuggestion? photoSuggestion;
  // Photo being analyzed; a newer photo or removing it discards the answer.
  String? _analyzedPhoto;

  Future<void> loadCategories() async {
    loadingCategories = true;
    notifyListeners();

    categories = await _repository.getCategories();
    loadingCategories = false;
    notifyListeners();
  }

  Future<void> analyzePhoto(String photoPath) async {
    final labeler = _photoLabeler;
    if (labeler == null) return;
    _analyzedPhoto = photoPath;
    photoSuggestion = null;
    analyzingPhoto = true;
    _notify();

    final suggestion = await labeler.suggest(photoPath);
    if (_analyzedPhoto != photoPath) return;
    photoSuggestion = suggestion;
    analyzingPhoto = false;
    _notify();
  }

  void clearPhotoSuggestion() {
    _analyzedPhoto = null;
    photoSuggestion = null;
    analyzingPhoto = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<SubmitResult?> submit(LostReportDraft draft) async {
    if (submitting) return null;
    submitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _tracker.measure(
        reportType: 'lost',
        operation: () => _repository.submit(draft),
      );
    } catch (_) {
      errorMessage = 'Unable to send the report. Please try again.';
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
