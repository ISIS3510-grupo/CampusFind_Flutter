import 'package:flutter/foundation.dart';

import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';

// Keeps the form state; the screen only renders it and forwards user actions.
class ReportLostItemController extends ChangeNotifier {
  ReportLostItemController(this._repository);

  final LostReportRepository _repository;

  List<String> categories = const [];
  bool loadingCategories = true;
  bool submitting = false;
  String? errorMessage;

  Future<void> loadCategories() async {
    loadingCategories = true;
    notifyListeners();

    categories = await _repository.getCategories();
    loadingCategories = false;
    notifyListeners();
  }

  Future<SubmitResult?> submit(LostReportDraft draft) async {
    if (submitting) return null;
    submitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _repository.submit(draft);
    } catch (_) {
      errorMessage = 'Unable to send the report. Please try again.';
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
