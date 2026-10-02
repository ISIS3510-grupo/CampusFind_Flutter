import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';

class FakeLostReportRepository implements LostReportRepository {
  FakeLostReportRepository({
    this.activeReports = const [],
    this.failSubmit = false,
    this.photoFailed = false,
  });

  final List<LostReport> activeReports;
  final bool failSubmit;
  final bool photoFailed;
  final List<LostReportDraft> submitted = [];

  @override
  Future<List<String>> getCategories() async => ['electronics', 'keys'];

  @override
  Future<List<LostReport>> getMyActiveReports() async => activeReports;

  @override
  Future<SubmitResult> submit(LostReportDraft draft) async {
    if (failSubmit) throw Exception('network');
    submitted.add(draft);
    return SubmitResult(
      'report-${submitted.length}',
      SubmitStatus.submitted,
      photoFailed: photoFailed,
    );
  }
}
