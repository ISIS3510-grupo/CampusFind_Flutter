import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';

// Repository pattern: the UI asks for reports and categories without knowing
// whether they come from Firestore, Storage or the local offline queue.
abstract class LostReportRepository {
  Future<List<String>> getCategories();

  Future<List<LostReport>> getMyActiveReports();

  Future<SubmitResult> submit(LostReportDraft draft);

  // Sends the reports saved while offline. Returns how many are still waiting.
  Future<int> syncPending();
}
