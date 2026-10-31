import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';

// Repository pattern: the UI asks for reports and categories without knowing
// whether they come from Firestore, Storage or the local offline queue.
abstract class LostReportRepository {
  Future<List<String>> getCategories();

  Future<List<LostReport>> getMyActiveReports();

  Future<SubmitResult> submit(LostReportDraft draft);

  // How many reports are saved on the device waiting to be sent.
  Future<int> pendingCount();

  // Sends the reports saved while offline. Returns how many are still waiting.
  Future<int> syncPending();
}
