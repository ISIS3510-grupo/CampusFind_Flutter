import 'package:campusfind_flutter/features/reports/data/pending_report_store.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps the queue on the device and removes sent reports', () async {
    final store = LocalPendingReportStore();
    const draft = LostReportDraft(
      title: 'Keys',
      category: 'keys',
      description: 'Two keys',
      locationName: 'ML',
      privateVerificationDetail: 'Red keychain',
    );

    await store.add(const PendingReport('report1', draft));
    await store.add(const PendingReport('report2', draft));
    // Saving the same id again replaces it instead of duplicating it.
    await store.add(const PendingReport('report1', draft));

    final saved = await LocalPendingReportStore().load();
    expect(saved.map((item) => item.reportId), ['report2', 'report1']);
    expect(saved.first.draft.privateVerificationDetail, 'Red keychain');

    await store.remove('report2');
    expect((await store.load()).single.reportId, 'report1');
  });
}
